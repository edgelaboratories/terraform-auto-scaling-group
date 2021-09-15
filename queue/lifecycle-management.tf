## Those rights are required by the ASG (or its ALB) to publish messages to the queue.
##
## Especially `sns:Publish`, see the following link:
## https://aws.amazon.com/premiumsupport/knowledge-center/ec2-auto-scaling-lifecycle-hook-error/

# First: configure a policy that allows to publish messages to the queue
# previously created.
data "aws_iam_policy_document" "sns" {
  statement {
    actions   = ["sqs:SendMessage", "sqs:GetQueueUrl"]
    resources = [aws_sqs_queue.this.arn]
  }

  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sqs_queue.this.arn]
  }
}

module "sns_policy_name" {
  source = "git@github.com:edgelaboratories/terraform-short-name.git?ref=v0.1.0"

  name          = "${var.unique_name}-lifecycle"
  max_length    = 128
  suffix_length = 4
}

resource "aws_iam_policy" "sns" {
  name        = module.sns_policy_name.name
  description = "Authorize the Auto Scaling service to interact with the SQS queue: ${aws_sqs_queue.this.name}"
  policy      = data.aws_iam_policy_document.sns.json
}

# Then, trust the AWS Auto Scaling to assume a role that permits to post the
# messages to SQS.
data "aws_iam_policy_document" "asg_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["autoscaling.amazonaws.com"]
    }
  }
}

module "lifecycle_role_name" {
  source = "git@github.com:edgelaboratories/terraform-short-name.git?ref=v0.1.0"

  name          = "${var.unique_name}-lifecycle"
  max_length    = 64
  suffix_length = 4
}

resource "aws_iam_role" "lifecycle" {
  name        = module.lifecycle_role_name.name
  description = "Authorize the Auto Scaling service to interact with the SQS queue: ${aws_sqs_queue.this.name}"

  assume_role_policy = data.aws_iam_policy_document.asg_assume_role.json

  tags = {
    Stack   = var.stack_id
    Managed = "terraform"
  }
}


resource "aws_iam_role_policy_attachment" "lifecycle" {
  role       = aws_iam_role.lifecycle.name
  policy_arn = aws_iam_policy.sns.arn
}
