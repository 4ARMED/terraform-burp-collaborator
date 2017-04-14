# Burpsuite Professional Private Collaborator Server using Terraform and Ansible

## Introduction

This is a [Terraform](https://terraform.io/) configuration to build a [Burp Private Collaborator Server](https://portswigger.net/burp/help/collaborator_deploying.html) on an [Amazon Web Services EC2 Instance](https://aws.amazon.com/). It uses Terraform to create the instance and then uses our [Ansible Burp Collaborator Server role](https://galaxy.ansible.com/4ARMED/burp-collaborator/) from Ansible Galaxy to provision the Burp service.

Some basic awareness of the AWS API and perhaps a little Terraform is assumed but if you're playing with Burp Collaborator you are hopefully technical enough to muddle through if not. Ping us questions if you get stuck [@4ARMED](https://twitter.com/4armed).

This configuration assumes you have registered your domain on the AWS Route53 Registrar. There's a very good reason why this is simpler, we don't have to mess about with working out NS servers for the hosted zone and waiting for NS updates to propagate. If we keep it all within the AWS family it's quicker and easier. It's almost like they've thought of this. ;-)

If you want to use an existing domain registered with another provider it is perfectly possible and there are instructions at the end on how to tweak this accordingly.

## *** WARNING ***

Just in case you've been living in a cave, everything in this README will cost you money on AWS. Even the free tier won't save you as it costs $0.50 per month for a hosted zone.

4ARMED are not in any way liable for your infrastructure costs. You should know by now not to just run things without understanding what you're doing. :-)

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

`ssh-keygen -b 2048 -t rsa -C private_burp@aws -f mykeypair`

Which will produce output like:
```
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

# You can call this what you like, it's only used to set the hostname
# on the Linux box
server_name = "burp-collaborator"

# Don't use this one. It's ours.
zone = "4armed.net"

# This is a pretty sensible default but again, change it if you like. The only downside is it's long which may
# cause problems if you only have limited injection space.
burp_zone = "collaborator" # This will result in collaborator.4armed.net

# Restrict this to places you will SSH from. The whole Internet is not all so friendly.
permitted_ssh_cidr_block = "0.0.0.0/0"
```

### Run Terraform

Now we're ready to run Terraform. First verify everything is ok by running plan:

`terraform plan`

Assuming you don't get any horrible errors you're ready to go.

![Image of yes kid](http://s2.quickmeme.com/img/ca/caeca14caf425c6de80bd94f29f63f0a1c5197fecabd50b1b1d916a79d9b8685.jpg)

`terraform apply`

Now sit back and behold the awesomeness of infrastructure as code.

The following operations will be performed:

* Create AWS security group permitting all Burp Collaborator traffic plus SSH to your _permitted_ssh_cidr_block_ CIDR.
* Create EC2 instance using Ubuntu Xenial (16.04) image for your chosen region in your default VPC.
* Create an A record for your chosen hostname in your AWS hosted zone pointing to the IP address of new EC2 instance
* Create an NS record for your chosen hostname pointing to the A record just created.
* Run the 4ARMED.burp-collaborator Ansible playbook on the EC2 instance to install and configure Burp Collaborator.

### Non-AWS registered domain

If you want to use this Terraform config but are using a domain registered somewhere other than AWS (and not transferred in) you can use a slightly different version of this Terraform plan. You will also need to manually update the DNS at your register to point an A record to your new EC2 instance and an NS record for the zone too.

There is a different version of [main.tf](main.tf) that does not include the route53 section at [main.tf.nonawsdomain](main.tf.nonawsdomain). To use this simply take a backup of the `main.tf` file and then copy this nonawsdomain version over it.

```
cp main.tf{,.aws}
cp main.tf{.nonawsdomain,}
```

Now run the `plan` and `apply` steps as above. It will output the public IP address that you will need for your dns updates but just in case you miss it somehow you can run anytime:

```
terraform output public_ip
35.176.22.202
```

## Testing

If everything went ok you should be able to plug the hostname of your new private server into Burp and test it out.

Fire up Burp Suite Professional and go to _Project options > Misc > Burp Collaborator Server_ and check the box for _Use a private Collaborator server_.

In _Server location_ enter the hostname of your server. Hint, this will be the value of `burp_zone` prepended to `zone` from [terraform.tfvars](terraform.tfvars). In our example `collaborator.4armed.net`. You will also need to tick the box for _Poll over unencrypted HTTP_ at the moment as we have used a self-signed certificate.

### Using a "proper" TLS certificate

If you would like to purchase a proper wildcard TLS certificate for use with this server you need to generate a more appropriate CSR (the default values are fairly generic). There is an Ansible playbook included in this folder to help you.

Once you have the CSR you can go and purchase a Wildcard TLS certificate with it and then upload it to your Burp server.

Here are the steps.

1. Edit [owntls.yml](owntls.yml) and set the different variables according to what you want in your certificate
2. Delete the generated CSR: `rm burp.csr`
3. `ansible-playbook -i inventory owntls.yml --tags tls`
4. Use the contents of the newly generated _burp.csr_ file to purchase your certificate.
5. Copy your new certificate to _burp.crt_
6. Copy any intermediate CA cert bundle to _intermediate.crt_
7. `ansible-playbook -i inventory playbook.yml --tags setup,restart`


## Destroying

When you've had your fun, if you want to kill the whole thing just run:

`terraform destroy`
