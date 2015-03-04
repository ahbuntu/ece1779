# ece1779

## Group Information
- Group Number 5
- Group members:
  - David Carney
  - Ahmadul Hassan

## Configuration
Project application stack:

- JRuby - implmentation of Ruby running atop a Java Virtual Machine
- Rails - web application framework for Ruby
- Sidekiq - single process asynchornous job queue, running on up to 4 threads
- Nginx - reverse proxy
- Puma - webserver running up to 16 threads internally
- MySQL - database

Each instance is configured for HTTP traffic only on port 80.
The ELB is configured for HTTP traffic on ports 80 and 8080.

## Database Instructions

Uses AWS RDS instance provided by course instructor/TA. The schema was modified 
and augmented from the original to add support for:

- sharing auto-scaling parameters between worker instances
- asynchronous image transformations (via Sidekiq)

## Account Instructions
Provided by email.

## Application Architecture
The project application is built using JRuby on Rails. It uses Nginx as a reverse proxy for the Puma web server and Sidekiq to asynchronously process jobs. User credentials, paths to the uploaded images and autoscaling configurations are stored on a MySQL database.

There is a basic authentication mechanism for the User and Manager pages. When a user chooses to upload an image, a temporary copy of the file is first saved on the server, and then uploaded to S3. Then 3 Sidekiq jobs are started to asynchronously perform the image transformations and finally upload to S3.

The manager page allows to start an ELB and add/remove workers to the pool. Launching an instance adds it to the worker pool and creates CloudWatch alarms correpsonding to the values specified. If auto-scaling is enabled, the reception of an alarm triggers an evaluation of whether to grow or shrink the cluster. 

The auto-scaling decision is made by taking the average CPU utilization of all workers and then determining whether the thresholds have been exceeded. Once a decision to grow or shrink the cluster is made, a cooldown period of 5 minutes is defined. During this period, all incoming alarm notifications will be ignored. This approach also allows us to use a decentralized alarm processing mechanism whereby any server on the cluster can perform the auto-scaling.

## Application Usage Instructions
You must first launch an instance with the AMI provided. This will become part of the worker pool if a load balancer is started.
Use the default settings unless specified as below: 

- Step 1. My AMIs:                      "ece1779-puma-006 - ami-c6055dae"
- Step 2. Instance Type:                "t2.small"
- Step 3.
    - Shutdown Behvaior:            "Terminate" 
    - Enable ***Detailed Monitoring***
- Step 6. Select existing group:        "webservers"
- Step 7. Credentials: select existing keypair:      "ece1779-general-keypair" (sent via email)

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


### Future Work

- enable direct-to-S3 uploads; modify the load-gen tool to take advantage of this mechanism
- 
