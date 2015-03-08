# ECE1779 Project #1

## Group Information

- Group Number 5
- Group members:
    - David Carney
    - Ahmadul Hassan

## Work Breakdown

We feel that there was a 50-50 split in work/effort between the two group memebers. Please don't hesitate to ask for further details about the (long list of) tasks. We believe, however, that this is immaterial since we both agree that work was evenly divided.

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

When a user chooses to upload an image, the original is uploaded synchronously to S3. Once complete, 3 Sidekiq jobs are enqueued to asynchronously perform the image transformations and upload their results to S3. After each upload the corresponding S3 key is written to the database. Once all uploads for a given image are complete, the original on disk is deleted. These workers contain additional support to download the original from S3 if it does not exists locally; hence they can safely be run from an instance.

A user requesting a given thumbnail via the web interface will have a valid URL returned immediately (i.e. performing the thumbnail generation synchronously, if necessary). This was added to guarantee a good user experience. In this case case the corresponding job remains enqueued, but exits immediately once its detect that the respective thumbnail has been uploaded to S3.

[Note: in our original implementation, the initial upload to S3 was performed asynchronously as well, but this proved problematic for thumbnail generation-on-demand because there is no guarantee that the instance requesting the thumbnails can download the S3 object or find a local copy on disk. In the end, user experience won over raw performance.]

From the ManagerUI one can start an ELB and add/remove instances (workers), as well as configure auto-scaling parameters. Launching an instance adds it to the worker pool and creates CloudWatch alarms correpsonding to the values specified. If auto-scaling is enabled, the reception of an alarm triggers an evaluation of whether to grow or shrink the cluster.

The auto-scaling decision is made by taking the average CPU utilization of all workers and then determining whether either of the low or high thresholds have been passed. Once a decision to grow or shrink the cluster is made, a cooldown period of 6 minutes is defined. During this period, all incoming alarm notifications are ignored. Once the cooldown finishes, alarms are checked and an auto-scaling decision made again. This is to handle the case where an alarm might have triggered during the cooldown.

Initially, the single instance creates all alarm subscriptions to point to itself. Once the ELB has one or more InService instances, the alarm subscriptions are instead pointed to the ELB. This approach also allows us to use a decentralized alarm processing mechanism whereby any server on the cluster can perform the auto-scaling. Note that, due to an AWS limitation, it's not possible to simply point alarm subscriptions to the ELB without an InService instance.

Two disadvantages of this approach is that debugging and state management is more complicated because alarms could be routed to different instances behind the ELB. Centralized logging (ex. to https://papertrailapp.com/) assists in the first case, whereas the latter relies on synchronizing with the AutoScale table in the database. In other words, the database is used to track whether or not a cooldown period is in effect. Currently, this isn't foolproof (i.e. a race condition exists where two alarms could simultaneously cause a scaling action), but in practice this has not been an issue. Adding some simple synchronization primites could remedy this possibility, at the cost of increased code and testing complexity.

## Application Usage Instructions

You must first launch an instance with the AMI provided. This will become part of the worker pool if/when a load balancer is started.
Use the default settings unless specified as below: 

- Step 1. My AMIs:                      "ece1779-puma-020 - ami-1692b77e"
- Step 2. Instance Type:                "t2.small"
- Step 3.
    - Shutdown Behvaior:            "Terminate" 
    - Enable ***Detailed Monitoring***
- Step 4. (no action required)
- Step 5. (no action required)
- Step 6. Select existing group:        "webservers"
- Step 7. Credentials: select existing keypair:      "ece1779-general-keypair" (sent via email)

Once the instance has launched:

1. Visit its public IP address in a browser
2. Log into the ManagerUI (instructions below)
3. Launch a load balancer (the code will automatically add the instance to the ELB)
4. From the EC2 console, select the created load balancer. In the bottom "Instances" pane, click "Edit" Connection Draining. Then enable ***Connection Draining*** with the default value and click "Save". 
5. Wait for the health checks on the ELB to pass, then visit its public DNS name

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

The application is designed to create a user on-demand when requests are sent from the load gen tool. This avoids the issue of requiring preconfigured users during testing. The adhoc users are created with the following credentials - user&lt;id&gt; and password&lt;id&gt;.

## Known Issues

Asynchronous S3 uploads and image processing (accomplished via Sidekiq) has obvious advantages, but it comes with some costs. Mainly:

- image transformation errors must now be reported asynchronously to the user (not currently done, but considered low priority);

- there can be a large queue of pending thumbnail generation jobs after web traffic to a given instance has decreased; this complicates cluster-shrinking behavior because we do not with to simply terminate an instance and lose all of the pending jobs.

Related to the second point, we modified our shrinking mechanism to immediately remove a selected instance from the ELB, but delay terminating it until its Sidekiq queues have drained (up to a maximum time). This is not ideal. Unfortunately, if a given instance has a disproportionately high number of jobs remaining after web traffic (i.e. uploads) has subsided then its load will continue to be high after the other instances in the cluster have gone idle. A better solution would be to use a central/shared dispatch queue. This should work rather seamlessly since the individual thumbnail generation jobs are written to handle downloading the original from S3 if it is not present on the local disk. This was left for future work.

Furthermore, an instance that has been removed from the cluster (but is still processing Sidekiq jobs) is obviously available to be added back into the cluster (if the cluster needs to grow). Doing so would eliminate the long startup time otherwise required by newly provisioned instances. This is not done, but would not be necessary with a shared job queue (since instances would be terminated almost immediately after traffic ceased).

Amazon ELB provides 2 types of session stickiness policies - "Load Balancer (LB) Cookies" and "Application Cookies". It is also possible to disable stickiness. We tried all 3 options and found that disabling stickiness provided the best load balancing characteristics. LB Cookies sticky sessions performed the worst. App-generated cookies were observed to provide the best compromise and therefore chosen. The impact of an imbalanced load is acutely experienced during the shrink cycle, since it is possible that 1 server will have a disproportionately high load, thereby discouraging the cluster from shrinking.

While the boot time of an instance is short, launching the JVM and getting the application stack to the point where it can respond to its first HTTP request takes significant time (about 5 minutes on a <code>t2.small</code> instance). This overhead is increased by the fact that the ELB itself has a health check that requires a consecutive number of "healthy" responses from an instance for it to be deemed "InService". Overall, growing a cluster takes significant time and, hence, it cannot quickly respond to sudden changes in load. Worse, such a long cooldown period exposes the cluster to the fact that many more alarms might occur over this time. Overall, it's obvious that finding a robust scaling heuristic/algorithm is difficult and very application-dependent.

We modified the ELB health check settings to aggressively bring an instance into "InService" mode and make it available for load balancing . However our testing revealed that under the right circumstances (fast connection speed, aggresive health checks, sticky sessions disabled), this could result in <code>503 Service Unavailable</code> errors being thrown. A combination of approaches were tried in an attempt to eliminate this problem, with limited success:

- longer health check values were chosen for the ELB (this gives the newly launched instance sufficient time to stabilize before directing traffic to it);

- the webserver's keep-alive value was increased to be 65 seconds (greater than the ELB's standard 60 seconds);

- the number of nginx workers was reduced from 4 to 2, which is inline with working on a <code>t2.small</code> instance (having only one CPU core). The idea here is that nginx is overwhelmed, but still accepting connections that will time out.

Ultimately, we left ELB stickiness enabled so as to keep the application more inline with a production setting.

## Future Work

Some ideas for future work include the following:

- enable direct-to-S3 uploads; modify the load-gen tool to take advantage of this AWS mechanism;
- use a central dispatch queue (i.e. Redis server) for asynchronous job management, allowing all instances to better share the load (it would be preferable to make jobs "stick" to a particular instance so as to avoid downloading the original image as much as possible);
- experiment with scaling the number of nginx and Sidekiq workers/threads to obtain higher throughput/performance;
- explore other CloudWatch metrics (ex. number of queued requests);
- further investigate the root cause of 503 errors when ELB stickiness is enabled;
- explore ways to reduce or eliminate the cooldown period, allowing the system to respond to alarms more intelligently.
