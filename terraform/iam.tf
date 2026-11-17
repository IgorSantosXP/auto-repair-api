# Pods get AWS credentials through EKS Pod Identity: the role is bound to the
# service account in each environment namespace, with access limited to
# publishing on the topic and consuming the service's own queue.
data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.project}-${var.service}-service"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "access" {
  statement {
    sid       = "PublishSagaMessages"
    actions   = ["sns:Publish"]
    resources = [for env in keys(var.environments) : local.topic_arns[env]]
  }

  statement {
    sid = "ConsumeOwnQueue"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [for queue in aws_sqs_queue.this : queue.arn]
  }
}

resource "aws_iam_role_policy" "access" {
  name   = "messaging"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.access.json
}

resource "aws_eks_pod_identity_association" "this" {
  for_each = var.environments

  cluster_name    = local.cluster_name
  namespace       = each.value
  service_account = var.service_account
  role_arn        = aws_iam_role.this.arn
}
