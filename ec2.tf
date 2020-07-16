//Locals
locals {
  ec2_instance_type  = "t2.micro"
  ec2_vpc_cidr       = "172.16.0.0/16"
  ec2_subnet_2a      = "172.16.10.0/24"
  keypair            = "barisw-aurora-kp"
}

//Data
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

//Resource
resource "aws_vpc" "public_aurora_vpc" {
  cidr_block           = local.ec2_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "public_aurora_vpc"
  }
}

resource "aws_subnet" "public_aurora_subnet" {
  vpc_id                  = "${aws_vpc.public_aurora_vpc.id}"
  cidr_block        	    = local.ec2_subnet_2a 
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_aurora_subnet"
  }
}

resource "aws_internet_gateway" "public_aurora_ig" {
  vpc_id = "${aws_vpc.public_aurora_vpc.id}"

  tags = {
    Name = "public_aurora_vpc"
  }
}

resource "aws_route_table" "public_aurora_rt" {
  vpc_id = "${aws_vpc.public_aurora_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.public_aurora_ig.id}"
  }

  tags = {
    Name = "public_aurora_rt"
  }
}


resource "aws_route_table_association" "public_aurora_subnet_to_rt_associateion" {
  subnet_id      = "${aws_subnet.public_aurora_subnet.id}"
  route_table_id = "${aws_route_table.public_aurora_rt.id}"
}

resource "aws_security_group" "public_aurora_ec2_sg" {
  name        = "Allow SSH"
  description = "Allow SSH"
  vpc_id      = "${aws_vpc.public_aurora_vpc.id}"

  ingress {
    description = "SSH from internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_instance" "public_aurora_ec2" {
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = local.ec2_instance_type
  key_name               = local.keypair
  vpc_security_group_ids = [ "${aws_security_group.public_aurora_ec2_sg.id}" ]
  subnet_id              = "${aws_subnet.public_aurora_subnet.id}"
}