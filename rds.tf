//Locals
locals {
  db_name            = "aurora-example-postgresql"
  db_user            = "postgres"
  db_password        = "postgres"
  engine_version     = "11.6"
  rds_instance_type  = "db.t3.medium"
  rds_vpc_cidr       = "10.10.0.0/16"
  rds_subnet_2a      = "10.10.10.0/24"
  rds_subnet_2b      = "10.10.20.0/24"
}

//Data
data "dns_a_record_set" "aurora_potsgresql-ip" {
  host = "${module.aurora.this_rds_cluster_endpoint}"
  
  depends_on = [ null_resource.wait_for_db_create ]
}

//Resource
resource "null_resource" "wait_for_db_create" {
  triggers = {
    "cluster-id" = "${module.aurora.this_rds_cluster_instance_ids[0]}"
  }

  provisioner "local-exec" {
    command = format("sleep %d",120)
  }
}

resource "aws_vpc" "aurora_db_vpc" {
  cidr_block = local.rds_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "aurora_db_vpc"
  }
}

resource "aws_subnet" "aurora_db_subnet_2a" {
  vpc_id                  = "${aws_vpc.aurora_db_vpc.id}"
  cidr_block        	    = local.rds_subnet_2a
  availability_zone       = "us-east-2a"
  tags = {
    Name = "aurora_db_subnet_2a"
  }
}

resource "aws_subnet" "aurora_db_subnet_2b" {
  vpc_id                  = "${aws_vpc.aurora_db_vpc.id}"
  cidr_block        	    = local.rds_subnet_2b
  availability_zone       = "us-east-2b"
  tags = {
    Name = "aurora_db_subnet_2b"
  }
}

resource "aws_db_parameter_group" "aurora_db_postgres11_parameter_group" {
  name        = "test-aurora-db-postgres11-parameter-group"
  family      = "aurora-postgresql11"
  description = "test-aurora-db-postgres11-parameter-group"
}

resource "aws_rds_cluster_parameter_group" "aurora_cluster_postgres11_parameter_group" {
  name        = "test-aurora-postgres11-cluster-parameter-group"
  family      = "aurora-postgresql11"
  description = "test-aurora-postgres11-cluster-parameter-group"
}

resource "aws_lb" "aurora-example-postgresql-lb" {
  name               = "aurora-example-postgresql-lb"
  internal           = true
  load_balancer_type = "network"
  subnets            = ["${aws_subnet.aurora_db_subnet_2a.id}", "${aws_subnet.aurora_db_subnet_2b.id}"]
  depends_on = [
    data.dns_a_record_set.aurora_potsgresql-ip
  ]
}

resource "aws_lb_target_group" "aurora-example-postgresql-lb-tg" {
  name        = "aurora-example-postgresql-lb-tg"
  port        = "${module.aurora.this_rds_cluster_port}"
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = "${aws_vpc.aurora_db_vpc.id}"
  depends_on = [
    data.dns_a_record_set.aurora_potsgresql-ip
  ]
}

resource "aws_lb_target_group_attachment" "aurora-example-postgresql-lb-tg-attach" {
  target_group_arn = "${aws_lb_target_group.aurora-example-postgresql-lb-tg.arn}"
  target_id        = "${data.dns_a_record_set.aurora_potsgresql-ip.addrs[0]}"
  port             = "${module.aurora.this_rds_cluster_port}"
  depends_on = [
    data.dns_a_record_set.aurora_potsgresql-ip
  ]
}


resource "aws_lb_listener" "aurora-example-postgresql-lb_listener" {
  load_balancer_arn = "${aws_lb.aurora-example-postgresql-lb.arn}"
  port              = "${module.aurora.this_rds_cluster_port}"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.aurora-example-postgresql-lb-tg.arn}"
  }
  depends_on = [
    data.dns_a_record_set.aurora_potsgresql-ip
  ]
}

//RDS Aurora module
module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 2.0"
  
  name                            = local.db_name
  engine                          = "aurora-postgresql"
  engine_version                  = local.engine_version
  subnets                         = ["${aws_subnet.aurora_db_subnet_2a.id}", "${aws_subnet.aurora_db_subnet_2b.id}"]
  allowed_cidr_blocks             = [ local.rds_subnet_2a, local.rds_subnet_2b ]
  vpc_id                          = "${aws_vpc.aurora_db_vpc.id}"
  replica_count                   = 1
  instance_type                   = local.rds_instance_type
  apply_immediately               = true
  skip_final_snapshot             = true
  db_parameter_group_name         = "${aws_db_parameter_group.aurora_db_postgres11_parameter_group.id}"
  db_cluster_parameter_group_name = "${aws_rds_cluster_parameter_group.aurora_cluster_postgres11_parameter_group.id}"
  security_group_description      = "Postgres security group"
  username			                  = local.db_user
  password			                  = local.db_password
}
