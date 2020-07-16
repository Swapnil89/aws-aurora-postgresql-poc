//Variables
variable "region" {
 default = "us-east-2"
}
variable "shared_cred_file" {
 default = "your-aws-creds"
}

//Provider
provider "aws" {
 region = "${var.region}"
 shared_credentials_file = "${var.shared_cred_file}"
 profile = "default"
}

