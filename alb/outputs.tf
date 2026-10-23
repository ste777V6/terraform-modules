output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer (point your app CNAME here)"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the load balancer (for Route 53 alias records)"
  value       = aws_lb.this.zone_id
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}

# Exposed with depends_on so anything using it (the ECS service) waits until the
# target group is attached to the ALB through the HTTPS listener. Without this,
# CreateService fails with "target group ... does not have an associated load balancer".
output "blue_target_group_arn" {
  description = "ARN of the live (blue) target group"
  value       = aws_lb_target_group.this["blue"].arn
  depends_on  = [aws_lb_listener.https]
}

output "target_group_arns" {
  description = "Map of target group ARNs keyed by colour (blue, green)"
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn }
}

output "target_group_names" {
  description = "Map of target group names keyed by colour (blue, green)"
  value       = { for k, tg in aws_lb_target_group.this : k => tg.name }
}

output "blue_target_group_resource_label" {
  description = "Resource label for ALBRequestCountPerTarget autoscaling"
  value       = "${aws_lb.this.arn_suffix}/${aws_lb_target_group.this["blue"].arn_suffix}"
}

output "acm_validation_cname_name" {
  description = "CNAME name to create at the external DNS provider for certificate validation"
  value       = tolist(aws_acm_certificate.this.domain_validation_options)[0].resource_record_name
}

output "acm_validation_cname_value" {
  description = "CNAME value to create at the external DNS provider for certificate validation"
  value       = tolist(aws_acm_certificate.this.domain_validation_options)[0].resource_record_value
}

output "log_bucket_name" {
  description = "Name of the ALB access-log bucket"
  value       = aws_s3_bucket.logs.id
}
