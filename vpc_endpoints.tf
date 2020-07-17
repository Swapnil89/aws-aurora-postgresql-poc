//Locals
locals {
  postgres_lb           = "${aws_lb.aurora-example-postgresql-lb.arn}"
  public_auroa_vpc_cidr = "${aws_vpc.public_aurora_vpc.cidr_block}"
  public_aurora_vpc_id  = "${aws_vpc.public_aurora_vpc.id}"
  public_aurora_subnets = ["${aws_subnet.public_aurora_subnet.id}"]
  aurora_db_vpc_cidr    = "${aws_vpc.aurora_db_vpc.cidr_block}"
  aurora_db_vpc_id      = "${aws_vpc.aurora_db_vpc.id}"
  aurora_db_subnets     = [ "${aws_subnet.aurora_db_subnet_2a.id}", "${aws_subnet.aurora_db_subnet_2b.id}" ]
  postgres_vpc_service  = "${aws_vpc_endpoint_service.aurora-example-postgresql-endpoint-service.service_name}"
  postgres_db_port      = "${module.aurora.this_rds_cluster_port}"
}

//Resource
resource "aws_vpc_endpoint_service" "aurora-example-postgresql-endpoint-service" {
  acceptance_required        = false
  network_load_balancer_arns = [ local.postgres_lb ]
  depends_on = [
    aws_lb_listener.aurora-example-postgresql-lb_listener
  ]
}


resource "aws_security_group" "postgres_endpoint_sg" {
  name        = "Allow DB connect"
  description = "Allow DB connect"
  vpc_id      = local.public_aurora_vpc_id

  ingress {
    description = "Allow DB connect"
    from_port   = local.postgres_db_port
    to_port     = local.postgres_db_port
    protocol    = "tcp"
    cidr_blocks = [ local.public_auroa_vpc_cidr ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_db_connect"
  }
}

resource "aws_vpc_endpoint" "postgres_endpoint" {
  vpc_id       = local.public_aurora_vpc_id
  subnet_ids   = local.public_aurora_subnets
  service_name = local.postgres_vpc_service
  vpc_endpoint_type = "Interface"
  security_group_ids = [
    "${aws_security_group.postgres_endpoint_sg.id}"
  ]
}

resource "aws_security_group" "secret_manager_endpoint_sg" {
  name        = "Allow HTTPS"
  description = "Allow HTTPS"
  vpc_id      = local.aurora_db_vpc_id

  ingress {
    description = "Allow HTTPS connect"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [ local.aurora_db_vpc_cidr ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_https_connect"
  }
}

resource "aws_vpc_endpoint" "secret_manager_endpoint" {
  vpc_id       = local.aurora_db_vpc_id
  subnet_ids   = local.aurora_db_subnets
  service_name = "com.amazonaws.us-east-2.secretsmanager"
  vpc_endpoint_type = "Interface"
  security_group_ids = [
    "${aws_security_group.secret_manager_endpoint_sg.id}"
  ]
  private_dns_enabled = true
}