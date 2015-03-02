# ece1779

<h2>Configuration</h2>
Project application stack
  - Puma - webserver running up to 16 threads internally
  - Nginx - reverse proxy
  - Sidekiq - single process asynchornous job queue, running on 1 thread

<h2>Database Instructions</h2>

<h2>Account Instructions</h2>
Provided by email.

<h2>Application Usage Instructions</h2>
You must first launch an instance with the AMI provided. This will become the master instance if the load balancer is started.
Use the default settings unless specified as below - 
  - Step 1
    - My AMIs:                      <specify-AMI-name>
  - Step 2
    - Instance Type:                "t2.small"
  - Step 3
    - Shutdown Behvaior:            "Terminate" 
    - Enable Termiantion Protection
    - Enable Detailed Monitoring
  - Step 5
    - Value:                        "master" 
  - Step 6
    - Select existing group:        "webservers"
  - Credentials
    - Select existing keypair:      "ece1779-general-keypair" (sent via email)

<b>The User UI</b>

  - Create an account in order to be able to upload images and view them. 
  - Clicking on “Upload an Image” will take you to the image upload form. 
    - You can only upload 1 image at a time.
    - All images uploaded will be stored under the ‘ece1779’ bucket in S3

  - The “My Images” link displays all the images you have uploaded so far. 


<b>The Manager UI</b>

  - If you click on the “Manager” link, you will be prompted for the manager credentials.

  - If you want to start multiple instances, first launch a load balancer by clicking on “Launch Load Balancer”.
The master instance can only be removed from the AWS console and not from the application.

  - You can manually scale the worker pool by clicking “Launch Another Instance” to increase the number of workers by 1, or shrink the pool by terminating instances.

  - You can purge all images stored in the S3 bucket by clicking on “Purge Images”

  - You can enable auto-scaling by clicking on the “Enable Auto-Scaling” checkbox followed by the “Update” button. The application will grow or shrink the worker pool based on the values provided.


<h2>Load Generator Tool Instructions</h2>
The tool was downloaded from the course website 
http://www.cs.toronto.edu/~delara/courses/ece1779/#projects

To run the program cd into <vm-directory>/ece1779LoadGenerator/bin
Run as:
  - java ece1779.loadgenerator.LoadGenerator server_ip_address_or_dns_name <port-optional>
