provider "aws" {
  region = "${var.region}"
  alias  = "${var.region}"
}

resource "aws_instance" "consul_server" {
  provider      = "aws.${var.region}"
  ami           = "${lookup(var.ami, join("-",list( var.region, var.platform)))}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${element(split(",", var.subnet_ids), count.index % length(split(",", var.subnet_ids)))}"
  count         = "${var.servers}"

  associate_public_ip_address = true
  vpc_security_group_ids      = ["${aws_security_group.consul_server.id}"]

  connection {
    user = "${lookup(var.user, var.platform)}"
    private_key = "${file(var.private_key)}"
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = "${var.disk_size}"
  }

    #Instance tags
  tags {
    Name = "${var.name}-${element(split(",", var.zones), count.index % length(split(",", var.zones)))}-${count.index + 1}"
    Type    = "${var.name}"
    Zone    = "${element(split(",", var.zones), count.index % length(split(",", var.zones)))}"
    Machine = "${var.instance_type}"
  }

  provisioner "file" {
    source = "${path.module}/../shared/scripts/${lookup(var.service_conf, var.platform)}"
    destination = "/tmp/${lookup(var.service_conf_dest, var.platform)}"
  }


  provisioner "remote-exec" {
    inline = [
      "echo ${var.servers} > /tmp/consul-server-count",
      "echo ${aws_instance.consul_server.0.private_dns} > /tmp/consul-server-addr",
    ]
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/shared/scripts/install.sh",
      "${path.module}/shared/scripts/install_nginx.sh",
      "${path.module}/shared/scripts/service.sh",
      "${path.module}/shared/scripts/ip_tables.sh",
    ]
  }
}

resource "aws_security_group" "consul_server" {
  provider    = "aws.${var.region}"
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Consul servers"

  tags { Name = "${var.name}" }

  // These are for internal traffic
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    self = true
  }

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    self = true
  }

  // Allow internal tcp traffic
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
}

  // Allow internal udp traffic
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  // These are for maintenance
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // This is for the administrative UI
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // This is for outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
