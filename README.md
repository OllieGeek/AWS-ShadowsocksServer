# aws-ss
## AWS Shadowsocks Server Deployer
This project is for easy deployment of a private [Shadowsocks service](https://shadowsocks.org/en/index.html) on AWS.

### Requirements
- AWS account (first 12 months are free)
- Public subnet (internet gateway and route to 0.0.0.0/0 configured)
  - *On a newly create account/region, all available subnets are public*
- Permission to run CloudFormation and create new: IAM roles, security groups, S3 buckets, and instances.
- Key pair (either [created using AWS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair) or [imported](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#how-to-generate-your-own-key-and-import-it-to-aws))
	- Allows logging in to the instance if required; during install can specify SSH access (default is allowed).
- Shadowsocks client - recommend [Outline](https://github.com/Jigsaw-Code/outline-client/releases)

### Install 

 1. Create/choose a public subnet, note the Subnet ID and VPC
 2. Create/import/choose a key pair, note the name
 3. Download the latest CloudFormation [template](https://github.com/OllieGeek/aws-ss/tree/master/cloudformation)
 4. Go to [CloudFormation](https://console.aws.amazon.com/cloudformation/home) and choose the desired region (top right) and choose *Create a stack* use *Upload a template to Amazon S3* and choose the file just downloaded
 5. Fill in the details and make sure to change the *'Enter a temporary password'* / *TempConfigPassword* click *Next* (bottom right) and *Next* again
 6. Tick the **I acknowledge that AWS CloudFormation might create IAM resources** box - the template creates a custom role that the instance uses to interact with its security group and the S3 bucket and click *Create*
 7. Waiting until the status becomes *CREATE_COMPLETE*, click the stack and choose the *Outputs* tab
 8. Click the S3 URL, enter the temporary password (*TempConfigPassword*) entered earlier
 9. One (or more if more than 1 *SSEndpoints* / *'How many endpoints to create?'* entered) endpoint details should appear
 10. Click the generated hyperlink to add to your Shadowsocks client
 
### How does it work?
The CloudFormation script creates the infrastructure, the (Amazon Linux 2 AMI) EC2 instance which gets created does a *git clone* of this repository and invokes the bash scripts:

 - [install_ss_server.sh](https://github.com/OllieGeek/aws-ss/blob/master/install_ss_server.sh "install_ss_server.sh") 
	 - installs dependencies, gets and builds [Shadowsocks](https://github.com/shadowsocks/shadowsocks-libev) and optimises the operating system
 - [create_ss_endpoint.sh](https://github.com/OllieGeek/aws-ss/blob/master/create_ss_endpoint.sh "create_ss_endpoint.sh")
	 - generates a random port and password, creates the configuration and adds the ports to the security group (firewall)
	 - runs *X* times based on the *SSEndpoints* / *How many endpoints to create?* setting
 - [server-start_gen.sh](https://github.com/OllieGeek/aws-ss/blob/master/server-start_gen.sh "server-start_gen.sh")
	 - generates the */opt/shadowsocks/server-start.sh* file, generates the *index.html* and uploads to the S3 bucket

### Todo
...
