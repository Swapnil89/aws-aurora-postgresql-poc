//Locals
locals {
    postgres_secret   = {
        engine   = "postgres"
        dbname   = "postgres"
        host     = "${aws_vpc_endpoint.postgres_endpoint.dns_entry[0].dns_name}"
        username = "${module.aurora.this_rds_cluster_master_username}"
        password = "${module.aurora.this_rds_cluster_master_password}"
        port     = "${module.aurora.this_rds_cluster_port}"
    }
    postgres_secret_name  = "test/postgres/secret"

    user1_secret   = {
        engine   = "postgres"
        dbname   = "postgres"
        host     = "${aws_vpc_endpoint.postgres_endpoint.dns_entry[0].dns_name}"
        username = "user1"
        password = "user1"
        port     = "5432"
    }
    user1_secret_name  = "test/user1/secret"
}

//Resource
resource "aws_secretsmanager_secret" "postgres_secret" {
  name_prefix = local.postgres_secret_name
}

resource "aws_secretsmanager_secret_version" "postgres_secret_value" {
  secret_id     = "${aws_secretsmanager_secret.postgres_secret.id}"
  secret_string = "${jsonencode(local.postgres_secret)}"
}

resource "aws_secretsmanager_secret_rotation" "postgres_secret_rotation" {
  secret_id           = "${aws_secretsmanager_secret.postgres_secret.id}"
  rotation_lambda_arn = "${aws_lambda_function.rotation_lambda.arn}"

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [
    data.aws_lambda_invocation.setup_user
  ]
}

resource "aws_secretsmanager_secret" "user1_secret" {
  name_prefix = local.user1_secret_name
  depends_on = [
      aws_secretsmanager_secret_version.postgres_secret_value
  ]
}

resource "aws_secretsmanager_secret_version" "user1_secret_value" {
  secret_id     = "${aws_secretsmanager_secret.user1_secret.id}"
  secret_string = "${jsonencode(local.user1_secret)}"
}

resource "aws_secretsmanager_secret_rotation" "user1_secret_rotation" {
  secret_id           = "${aws_secretsmanager_secret.user1_secret.id}"
  rotation_lambda_arn = "${aws_lambda_function.rotation_lambda.arn}"

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [
    data.aws_lambda_invocation.setup_user
  ]
}