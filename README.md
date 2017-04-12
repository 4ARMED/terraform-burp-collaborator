# Burpsuite Professional Private Collaborator Server using Terraform and Ansible

## Introduction

This is a [Terraform](https://terraform.io/) configuration to build a [Burp Private Collaborator Server](https://portswigger.net/burp/help/collaborator_deploying.html) on an [Amazon Web Services EC2 Instance](https://aws.amazon.com/). It uses Terraform to create the instance and then uses our [Ansible Burp Collaborator Server role](https://galaxy.ansible.com/4ARMED/burp-collaborator/) from Ansible Galaxy to provision the Burp service.

Some basic awareness of the AWS API and perhaps a little Terraform is assumed but if you're playing with Burp Collaborator you are hopefully technical enough to muddle through if not. Ping us questions if you get stuck [@4ARMED](https://twitter.com/4armed).

## *** WARNING ***

Just in case you've been living in a cave, everything in this README will cost you money on AWS. Even the free tier won't save you as it costs $0.50 per month for a hosted zone.

4ARMED are not in any way liable for your infrastructure costs. You're big boys and girls now, don't just run things without understanding what you're doing. :-)


## Steps

### Set up AWS API user

To use this you need to perform a couple of additional steps to be ready to run Terraform. The first is you need an AWS account and a valid access ID and secret (create a programmatic-only IAM user). I'm not going to talk through how to do this as it'll double the length of this document. Sorry! Try here http://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html.

Once you have these values they can be plugged in to this to configure the [AWS Provider](https://www.terraform.io/docs/providers/aws/).

### Configure AWS Credentials

This config assumes you will use the AWS CLI credentials store. First install it if you have not already:

`pip install aws-cli`

Then configure it:

```
aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: ENTER
```

### Clone this repo to a local folder

```
git clone https://github.com/4ARMED/terraform-burp-collaborator.git
cd terraform-burp-collaborator
```

It is assumed that everything else in this doc will be performed with the current working directory in this folder.

### Generate an SSH key pair

We're going to assume you don't have a keypair already in AWS so we'll generate one now and upload it to AWS. You can skip this step if you already have one, just update [terraform.tfvars](terraform.tfvars) to use the right _key_pair_name_ and place the public key file in this directory.

Feel free to use a different comment or algorithm and it's best to set a passphrase on the key (obvs).

```
$ ssh-keygen -b 2048 -t rsa -C private_burp@aws -f mykeypair
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in mykeypair.
Your public key has been saved in mykeypair.pub.
```

Make sure your keypair file has the same name as your _key_pair_name_ variable as we will look there to upload it to AWS.

### Copy Burp jar

You will need to supply your own copy of the latest Burp Suite Professional jar file. Go buy one at the [Portswigger website](https://portswigger.net/burp/). When you have it copy the jar into this folder. The Ansible playbook will glob in this directory, if you put more than one in you are at the mercy of glob as to which ends up on your server.

In this example I've used the latest version at the time of writing. Given the rate of release these instructions will be out of date in a couple of weeks.

`cp /some/path/to/burpsuite_pro_v1.7.21.jar .`

### Configure Terraform variables

Edit the file [terraform.tfvars](terraform.tfvars).

```
# Use whatever region you prefer
region = "eu-west-2"

# Here we are using a different AWS profile from default, you don't have to but this is how if you need to.
profile = "research"

# Adjust according to your region and AZ preference
availability_zone = "eu-west-2a"

# This is the smallest (read cheapest) instance type available. Works ok with this.
instance_type = "t2.nano"

# Make sure the name of your keypair matches the filename minus the .pub suffix.
key_name = "mykeypair"

# You can call this what you like
server_name = "burp-collaborator"

# Don't use this one. It's ours.
zone = "4armed.net"

# This is a pretty sensible default but again, change it if you like. The only downside is it's long which may
# cause problems if you only have limited injection space.
burp_zone = "collaborator" # This will result in collaborator.4armed.net

# Restrict this to places you will SSH from. The whole Internet is not all so friendly.
permitted_ssh_cidr_block = "0.0.0.0/0"

# This is an important one. If you bought/registered your domain with AWS (or transferred it in) leave as false.
# If you specify true we will create a new Route53 hosted zone. If false we assume the nameservers are already managed by AWS.
domain_registered_with_other = false
```

### Run Terraform

Now we're ready to run Terraform. First verify everything is ok by running plan:

`terraform plan`

Assuming you don't get any horrible errors you're ready to go.

![Image of yes kid](http://s2.quickmeme.com/img/ca/caeca14caf425c6de80bd94f29f63f0a1c5197fecabd50b1b1d916a79d9b8685.jpg)

`$ terraform apply`

Now sit back and behold the awesomeness of infrastructure as code.

When it's all built there should only be one task left to do.

### Update your register name servers

We need to tell our registrar to use Amazon Web Services' name servers for our domain (assuming you didn't register the domain with AWS). The NS records you need can be viewed from the output of:

`terraform output name_servers`

#### Bonus for Namecheap customers

If you are using Namecheap as your registrar then you can use our handy Ruby script to update the NS records automatically via their API. Bear in mind you will need API access to Namecheap which is not enabled by default. Read [this doc](https://www.namecheap.com/support/api/intro.aspx) to tell you how to enable it.

Assuming you have done that, you will have an API username, a regular username (that you use on the website, usually the same as the API one) and an API key. Use those values to set the following environment variables on your local machine as follows.

```
export NAMECHEAP_MYIP=$(curl -s http://ip.4armed.com)
export NAMECHEAP_API_USERNAME="_your_namecheap_api_username_"
export NAMECHEAP_USERNAME="_your_namecheap_username_"
export NAMECHEAP_API_KEY="_your_namecheap_api_key_"
```

With these set, now you can run the nameserver update script for Namecheap:

```
$ ./set_route53_ns.rb 4armed.net
[*] You are about to update 4armed.net to use DNS servers ns-1276.awsdns-31.org,ns-1729.awsdns-24.co.uk,ns-212.awsdns-26.com,ns-828.awsdns-39.net
[*] Are you sure you want to do this? (y/N): y
[{:domain=>"4armed.net", :updated=>"true"}]
```

## Testing

If everything went ok you should be able to plug the hostname of your new private server into Burp and test it out.

Fire up Burp Suite Professional and go to _Project options > Misc > Burp Collaborator Server_ and check the box for _Use a private Collaborator server_.

In _Server location_ enter the hostname of your server. Hint, this will be the value of `burp_zone` prepended to `zone` from [terraform.tfvars](terraform.tfvars). In our example `collaborator.4armed.net`. You will also need to tick the box for _Poll over unencrypted HTTP_ at the moment as we have used a self-signed certificate.

If you would like to purchase a proper wildcard TLS certificate for use with this server go see the Ansible Playbook documentation for how to do this. (If the doc isn't there it's because I haven't managed to write it yet but if you read the playbook you may be able to work it out - it's to do with tags).

## Destroying

When you've had your fun, if you want to kill the whole thing just run:

`terraform destroy`
