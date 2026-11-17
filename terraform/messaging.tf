# The OS Service queue: receives every event addressed to `destination = os`
# (Billing and Execution replies to the saga). Failed messages are retried by
# SQS and moved to the DLQ after 3 receives.
resource "aws_sqs_queue" "dlq" {
  for_each = var.environments

  name                      = "${var.project}-${each.key}-${var.service}-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "this" {
  for_each = var.environments

  name                       = "${var.project}-${each.key}-${var.service}"
  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 10
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = 3
  })
}

data "aws_iam_policy_document" "queue" {
  for_each = var.environments

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.this[each.key].arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [local.topic_arns[each.key]]
    }
  }
}

resource "aws_sqs_queue_policy" "this" {
  for_each = var.environments

  queue_url = aws_sqs_queue.this[each.key].id
  policy    = data.aws_iam_policy_document.queue[each.key].json
}

resource "aws_sns_topic_subscription" "this" {
  for_each = var.environments

  topic_arn            = local.topic_arns[each.key]
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.this[each.key].arn
  raw_message_delivery = true
  filter_policy        = jsonencode({ destination = [var.service] })
}
