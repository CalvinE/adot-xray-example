output "alb_dns_name" {
  description = "The dns name for the ALB"
  value       = aws_alb.this.dns_name
}

output "alb_arn" {
  description = "The ARN of the ALB"
  value       = aws_alb.this.arn
}
// TODO: populate this...
