output "queue_arn" {
  description = "The ARN of the queue"
  value       = aws_sqs_queue.this.arn
}

output "queue_name" {
  description = "The name of the queue"
  value       = aws_sqs_queue.this.name
}

output "policy_arn" {
  description = "The SQS queue policy"
  value       = aws_iam_policy.sqs.arn
}

output "role_lifecycle_management_arn" {
  description = "The role ARN that allows to post into SQS"
  value       = aws_iam_role.lifecycle.arn
}
