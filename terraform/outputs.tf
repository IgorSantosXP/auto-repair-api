output "queue_urls" {
  value = { for env, queue in aws_sqs_queue.this : env => queue.url }
}

output "dlq_urls" {
  value = { for env, queue in aws_sqs_queue.dlq : env => queue.url }
}

output "role_arn" {
  value = aws_iam_role.this.arn
}
