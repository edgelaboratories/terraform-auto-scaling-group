module "queue_name" {
  source = "git@github.com:edgelaboratories/terraform-short-name.git?ref=v0.1.0"

  // SQS queue name must be <=80
  name          = var.unique_name
  max_length    = 80
  suffix_length = 4
}

## The SQS queue itself
resource "aws_sqs_queue" "this" {
  name = module.queue_name.name

  message_retention_seconds = var.retention_period

  tags = {
    Name    = var.pretty_name
    Stack   = var.stack_id
    Managed = "terraform"
  }
}

# Grant the permissions to read/write into the SQS queue, so that Mufasa can
# read and process the events posted by the autoscaling group.
data "aws_iam_policy_document" "sqs" {
  statement {
    sid    = "ForMufasa"
    effect = "Allow"

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
    ]

    resources = [
      aws_sqs_queue.this.arn
    ]
  }
}

# If the queue policy is created too early after the SQS queue itself, it can fail with:
#
#     Error: "policy" contains an invalid JSON policy
#
# The AWS documentation says there's a propagation delay up to 60 seconds
# Let's wait a bit (hopefully enough!) before proceeding with the rest of the queue configuration.
#
# See: https://github.com/hashicorp/terraform-provider-aws/issues/13980#issuecomment-725069967
resource "time_sleep" "wait_for_the_queue" {
  depends_on = [aws_sqs_queue.this]

  create_duration = "10s"
}

resource "aws_sqs_queue_policy" "this" {
  depends_on = [time_sleep.wait_for_the_queue]

  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.sqs.json
}

module "sqs_policy_name" {
  source = "git@github.com:edgelaboratories/terraform-short-name.git?ref=v0.1.0"

  name          = "${var.unique_name}-sqs"
  max_length    = 128
  suffix_length = 4
}

# Grant the policy to the requested role.
resource "aws_iam_policy" "sqs" {
  name        = module.sqs_policy_name.name
  description = "Read and write into the SQS queue: ${aws_sqs_queue.this.name}"
  policy      = aws_sqs_queue_policy.this.policy
}

resource "aws_iam_role_policy_attachment" "enable_sqs" {
  role       = var.attach_to_role
  policy_arn = aws_iam_policy.sqs.arn
}
