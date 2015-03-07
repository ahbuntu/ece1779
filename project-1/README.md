# ECE1779 Project #1

## Group Information

- Group Number 5
- Group members:
    - David Carney
    - Ahmadul Hassan

## Configuration

Project application stack:

- JRuby - implmentation of Ruby running atop the Java Virtual Machine (JVM)
- Rails - web application framework for Ruby
- Sidekiq - single process asynchornous job queue, configured to run on up to 4 threads
- Nginx - reverse proxy
- Puma - webserver configured to run on up to 16 threads internally
- MySQL - database

Each instance is configured for HTTP traffic only on port 80.
The ELB is configured for HTTP traffic on ports 80 and 8080.

Instructions on how to configure an (Ubuntu) server for use with the aforementioned stack are available under the <code>./vagrant</code> project directory.

## Database Instructions

Uses AWS RDS instance provided by course instructor/TA. The schema was modified 
and augmented from the original to add support for:

- sharing auto-scaling parameters between worker instances
- asynchronous image transformations (via Sidekiq)

See db/schema.rb for details.

## Account Instructions
Provided by email.

## Application Architecture

The project application is built using JRuby on Rails. It uses Nginx as a reverse proxy for the Puma web server and Sidekiq to asynchronously process jobs (image uploads and thumbnail generation using ImageMagick). Sidekiq is backed by a Redis server. User credentials, paths to the uploaded images, and autoscaling configurations are stored on a MySQL database. There is a basic authentication mechanism for the User and Manager pages. 

When a user chooses to upload an image, a temporary copy of the file is first saved on the instance where the image was uploaded. It is then asynchronously uploaded to S3 with a high-priority Sidekiq job. Once complete, 3 Sidekiq jobs are enqueued to asynchronously perform the image transformations and upload their results to S3. After each upload the corresponding S3 key is written to the database. Once all uploads for a given image are complete, the original on disk is deleted.

From the ManagerUI one can start an ELB and add/remove instances (workers), as well as configure auto-scaling parameters. Launching an instance adds it to the worker pool and creates CloudWatch alarms correpsonding to the values specified. If auto-scaling is enabled, the reception of an alarm triggers an evaluation of whether to grow or shrink the cluster.

The auto-scaling decision is made by taking the average CPU utilization of all workers and then determining whether either of the low or high thresholds have been passed. Once a decision to grow or shrink the cluster is made, a cooldown period of 6 minutes is defined. During this period, all incoming alarm notifications are ignored. Once the cooldown finishes, alarms are checked and an auto-scaling decision made again. This is to handle the case where an alarm might have triggered during the cooldown.

Initially, the single instance creates all alarm subscriptions to point to itself. Once the ELB has one or more InService instances, the alarm subscriptions are instead pointed to the ELB. This approach also allows us to use a decentralized alarm processing mechanism whereby any server on the cluster can perform the auto-scaling. Note that, due to an AWS limitation, it's not possible to simply point alarm subscriptions to the ELB without an InService instance.

Two disadvantages of this approach is that debugging and state management is more complicated because alarms could be routed to different instances behind the ELB. Centralized logging (ex. to https://papertrailapp.com/) assists in the first case, whereas the latter relies on synchronizing with the AutoScale table in the database. In other words, the database is used to track whether or not a cooldown period is in effect. Currently, this isn't foolproof (i.e. a race condition exists where two alarms could simultaneously cause a scaling action), but in practice this has not been an issue. Adding some simple synchronization primites could remedy this possibility, at the cost of increased code and testing complexity.

## Application Usage Instructions

You must first launch an instance with the AMI provided. This will become part of the worker pool if/when a load balancer is started.
Use the default settings unless specified as below: 

- Step 1. My AMIs:                      "ece1779-puma-006 - ami-c6055dae"
- Step 2. Instance Type:                "t2.small"
- Step 3.
    - Shutdown Behvaior:            "Terminate" 
    - Enable ***Detailed Monitoring***
- Step 5. (no action required)
- Step 6. Select existing group:        "webservers"
- Step 7. Credentials: select existing keypair:      "ece1779-general-keypair" (sent via email)

Once the instance has launched:

1. visit its public IP address in a browser
2. log into the ManagerUI (instructions below)
3. launch a load balancer (the code will automatically add the instance to the ELB)
4. wait for the health checks on the ELB to pass, then visit its public DNS name

### The User UI

- Create an account in order to be able to upload images and view them. 
- Clicking on “Upload an Image” will take you to the image upload form. 
    - You can only upload 1 image at a time.
    - All images uploaded will be stored under the ‘ece1779’ bucket in S3
- The “My Images” link displays all the images you have uploaded so far.

### The Manager UI

- If you click on the “Manager” link, you will be prompted for the manager credentials.

- If you want to start multiple instances, first launch a load balancer by clicking on “Launch Load Balancer”.

- You can manually scale the worker pool by clicking “Launch Another Instance” to increase the number of workers by 1, or shrink the pool by terminating one instance at a time.

- You can purge all images stored in the S3 bucket by clicking on “Purge Images”. There is a possibility that the request may timeout for a very large number of images.

- You can enable auto-scaling by clicking on the “Enable Auto-Scaling” checkbox followed by the “Update” button. The application will grow or shrink the worker pool based on the values provided.

### Load Generator Tool Instructions

The application was load tested using the provided tool. It was downloaded from the course website 
http://www.cs.toronto.edu/~delara/courses/ece1779/#projects

## Known Issues

Asynchronous S3 uploads and image processing (accomplished via Sidekiq) has obvious advantages, but it comes with some costs. Mainly:

- image transformation errors must now be reported asynchronously to the user (not currently done);

- image transformations are currently expected to run on the same instance where the image was uploaded. This is simple, but complicates shutdown/termination selection and behaviour because the cluster has to be careful not to quickly terminate an instance that has outstanding jobs.

Related to the last point, we modified our shrinking mechanism to immediately remove a selected instance from the ELB, but delay terminating it until its Sidekiq queues have drained (up to a maximum time). This is not ideal. Unfortunately, if a given instance has a disproportionately high number of jobs remaining after web traffic (i.e. uploads) has subsided then its load will continue to be high after the other instances in the cluster have gone idle. A better solution would be to use a central/shared dispatch queue. This would require modifying the image transformation jobs to be able to download the original image from S3 if it is not already present locally. This was left for future work.

Furthermore, an instance that has been removed from the cluster (but is still processing Sidekiq jobs) is obviously available to be added back into the cluster (if the cluster needs to grow). Doing so would eliminate the long startup time otherwise required by newly provisioned instances. This is not done and would not be necessary with a shared job queue (since instances would be terminated almost immediately after traffic ceased).

Session stickiness was enabled on the ELB, but this was discovered to cause disproportionate load when the cluster was grown or shrunk. This was not investigated and, instead, stickiness was disabled.

While the boot time of an instance is short, launching the JVM and getting the application stack to the point where it can respond to its first HTTP request takes significant time (about 5 minutes on a <code>t2.small</code> instance). This overhead is increased by the fact that the ELB itself has a health check that requires a consecutive number of "healthy" responses from an instance for it to be deemed "InService". Overall, growing a cluster takes significant time and, hence, it cannot quickly respond to sudden changes in load. Worse, 
such a long cooldown period exposes the cluster to the fact that many more alarms might occur over this time. Overall, it's obvious that finding a robust scaling heuristic/algorithm is difficult and very application-dependent.

## Future Work

Some ideas for future work include the following:

- enable direct-to-S3 uploads; modify the load-gen tool to take advantage of this AWS mechanism;
- use a central dispatch queue (i.e. Redis server) for asynchronous job management, allowing all instances to share the load;
- experiment with scaling the number of nginx and Sidekiq workers/threads to obtain higher throughput/performance;
- enable ELB session stickiness (and ensure load is well-balanced);
- explore other CloudWatch metrics (ex. number of queued requests);
- explore ways to reduce or eliminate the cooldown period, allowing the system to respond to alarms more intelligently.
