output "name" {
  value = aws_autoscaling_group.this.name
}

output "arn" {
  value = aws_autoscaling_group.this.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.this.*.arn
}
