//Locals
locals {
  zip_file = "src/lambda.zip"
  lambda_vpc_id          = "${aws_vpc.aurora_db_vpc.id}"
  lambda_vpc_cidr        = "${aws_vpc.aurora_db_vpc.cidr_block}"
  lambda_subnets         = [ "${aws_subnet.aurora_db_subnet_2a.id}", "${aws_subnet.aurora_db_subnet_2b.id}" ]
  master_secret_name     = "${aws_secretsmanager_secret.postgres_secret.name}"
}

//Resource

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = local.lambda_vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [ local.lambda_vpc_cidr ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}


resource "aws_lambda_permission" "allow_secret_manager_invoke_secret_rotation" {
   statement_id  = "AllowSecretManagerInvoke"
   action        = "lambda:InvokeFunction"
   function_name = "${aws_lambda_function.rotation_lambda.function_name}"
   principal     = "secretsmanager.amazonaws.com"
 }

resource "aws_iam_role" "lambda_rotation_iam_role" {
  name = "lambda_rotation_iam_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy"  "lambda_rotation_iam_policy" {
  name = "lambda_rotation_iam_role_policy"
  policy = file("policies/lambda_rotation_iam_policy.json")
}

resource "aws_iam_policy_attachment" "lambda_rotation_iam_policy_attach" {
  name       = "lambda_rotation_iam_policy_attach"
  roles      = ["${aws_iam_role.lambda_rotation_iam_role.name}"]
  policy_arn = "${aws_iam_policy.lambda_rotation_iam_policy.arn}"
}


resource "aws_lambda_function" "rotation_lambda" {
  filename      = local.zip_file
  function_name = "secret_rotation"
  role          = "${aws_iam_role.lambda_rotation_iam_role.arn}"
  handler       = "secret_rotation.lambda_handler"

  source_code_hash = "${filebase64sha256(local.zip_file)}"

  runtime = "python3.6"
  
  vpc_config {
    subnet_ids         = local.lambda_subnets
    security_group_ids = [ "${aws_security_group.allow_tls.id}" ]
  }
    
  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.us-east-2.amazonaws.com"
    }
  }
}

resource "aws_lambda_permission" "allow_secret_manager_invoke_manage_users" {
   statement_id  = "AllowSecretManagerInvoke"
   action        = "lambda:InvokeFunction"
   function_name = "${aws_lambda_function.manage_users_lambda.function_name}"
   principal     = "secretsmanager.amazonaws.com"
 }


resource "aws_iam_role" "lambda_manage_users_iam_role" {
  name = "lambda_manage_users_iam_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy"  "lambda_manage_users_iam_policy" {
  name = "lambda_manage_users_iam_role_policy"
  policy = file("policies/lambda_manage_users_iam_policy.json")
}

resource "aws_iam_policy_attachment" "lambda_manage_users_iam_policy_attach" {
  name       = "lambda_manage_users_iam_policy_attach"
  roles      = ["${aws_iam_role.lambda_manage_users_iam_role.name}"]
  policy_arn = "${aws_iam_policy.lambda_manage_users_iam_policy.arn}"
}


resource "aws_lambda_function" "manage_users_lambda" {
  filename      = local.zip_file
  function_name = "pg_manage_users"
  role          = "${aws_iam_role.lambda_manage_users_iam_role.arn}"
  handler       = "pg_manage_users.lambda_handler"

  source_code_hash = "${filebase64sha256(local.zip_file)}"

  runtime = "python3.6"
  
  vpc_config {
    subnet_ids         = local.lambda_subnets
    security_group_ids = [ "${aws_security_group.allow_tls.id}" ]
  }
    
  environment {
    variables = {
      MASTER_SECRET_NAME       = local.master_secret_name
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.us-east-2.amazonaws.com"
    }
  }
}
