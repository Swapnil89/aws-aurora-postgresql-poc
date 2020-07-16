//Output
output "aurora_cluster_endpoint" {
  value       = module.aurora.this_rds_cluster_endpoint
  description = "Aurora cluster endpoint"	
}

output "aurora_master_username" {
  value       = module.aurora.this_rds_cluster_master_username
  description = "Aurora Master User"	
}

output "aurora_master_password" {
  value       = module.aurora.this_rds_cluster_master_password	
  description = "Aurora Master Password"	
}

output "aurora_cluster_port" {
  value       = module.aurora.this_rds_cluster_port
  description = "Aurora Cluster port"	
}

output "postgres_vpc_endpoint_host" {
  value       = aws_vpc_endpoint.postgres_endpoint.dns_entry[0].dns_name
  description = "Postgres VPC Endpoint DNS Host"
}

output "instance_ip_addr" {
  value       = aws_instance.public_aurora_ec2.public_ip
  description = "The public IP address of the main server instance."
}

output "setup_user_result" {
  description = "Setup User Lambda execution"
  value       = "${data.aws_lambda_invocation.setup_user.result}"
}