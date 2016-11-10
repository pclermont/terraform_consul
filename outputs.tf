output "names" {
  value = "${join(",", aws_instance.consul_server.*.id)}"
}

output "private_ips" {
  value = "${join(",", aws_instance.consul_server.*.private_ip)}"
}

output "public_ips"  {
  value = "${join(",", aws_instance.consul_server.*.public_ip)}"
}