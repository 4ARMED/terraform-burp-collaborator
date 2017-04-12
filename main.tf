provider "aws" {
  region = "${var.region}"
  profile = "${var.profile}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "key" {
  key_name = "${var.key_name}"
  public_key = "${file("${var.key_name}.pub")}"
}

resource "aws_instance" "collaborator" {
  ami = "${data.aws_ami.ubuntu.id}"
  instance_type = "${var.instance_type}"
  key_name = "${aws_key_pair.key.key_name}"

  tags {
    Name = "${var.server_name}"
  }

  security_groups = [
    "${aws_security_group.collaborator_sg.name}"
  ]

  provisioner "local-exec" {
    command = "sleep 30 && ansible-galaxy install -r requirements.yml && echo \"[collaborator]\n${aws_instance.collaborator.public_ip} ansible_connection=ssh ansible_ssh_user=ubuntu ansible_ssh_private_key_file=${var.key_name}\" > inventory && ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook -i inventory playbook.yml --extra-vars \"server_hostname=${var.server_name} burp_server_domain=${var.burp_zone}.${var.zone} burp_local_address=${aws_instance.collaborator.private_ip} burp_public_address=${aws_instance.collaborator.public_ip}\""
  }
}

resource "aws_security_group" "collaborator_sg" {
  name = "collaborator-sg"
  description = "Allow access to Burp Collaborator services"

  # SSH
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${var.permitted_ssh_cidr_block}"]
  }

  # SMTP
  ingress {
    from_port = 25
    to_port = 25
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS
  ingress {
    from_port = 53
    to_port = 53
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SMTPS
  ingress {
    from_port = 465
    to_port = 465
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SMTP
  ingress {
    from_port = 587
    to_port = 587
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Polling (HTTP)
  ingress {
    from_port = 9090
    to_port = 9090
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Polling (HTTPS)
  ingress {
    from_port = 9443
    to_port = 9443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route53_zone" "create" {
  name = "${var.zone}"
  count = "${var.domain_registered_with_other}"
}

data "aws_route53_zone" "registered" {
  name = "${var.zone}"
}

resource "aws_route53_record" "a" {
  zone_id = "${data.aws_route53_zone.registered.zone_id}"
  name    = "${var.burp_zone}.${var.zone}"
  type    = "A"
  ttl     = "5"
  records = ["${aws_instance.collaborator.public_ip}"]
}

resource "aws_route53_record" "ns" {
  zone_id = "${data.aws_route53_zone.registered.zone_id}"
  name    = "${var.burp_zone}.${var.zone}"
  type    = "NS"
  ttl     = "5"
  records = ["${var.burp_zone}.${var.zone}."]
}
