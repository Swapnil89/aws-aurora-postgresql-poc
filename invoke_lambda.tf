locals {
  input_event = {
    MasterSecretName = "${aws_secretsmanager_secret.postgres_secret.name}"
    UserSecretName = "${aws_secretsmanager_secret.user1_secret.name}"
    Step = "CreateUser"
  }
  manage_users_lambda = "${aws_lambda_function.manage_users_lambda.function_name}"
}

data "aws_lambda_invocation" "setup_user" {
  function_name = local.manage_users_lambda
  input = "${jsonencode(local.input_event)}"
  depends_on = [
      aws_secretsmanager_secret_version.user1_secret_value,
      aws_lambda_function.manage_users_lambda
  ]
}
