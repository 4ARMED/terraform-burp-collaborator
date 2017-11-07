output "name_servers" {
  description = "The AWS DNS servers to be used to update the zone with your registar."
  value = "${data.aws_route53_zone.burp.name_servers}"
}

output "private_ip" {
  description = "The private IP address of the collaborator server."
  value = "${aws_instance.collaborator.private_ip}"
}

output "public_ip" {
  description = "The public IP address of the collaborator server."
  value = "${aws_instance.collaborator.public_ip}"
}
