output "vpc_id" {
  description = "The id of the VPC"
  value       = aws_vpc.this.id
}

output "internet_gateway_id" {
  description = "The internet gateway id."
  value       = aws_internet_gateway.this.id
}
