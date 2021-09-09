locals {
  launching_hook = merge({
    name                 = "launching"
    default_result       = "ABANDON"
    heartbeat_timeout    = 600 # AWS default is 3600
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }, lookup(var.lifecycle_hooks, "launching", {}))

  terminating_hook = merge({
    name                 = "terminating"
    default_result       = "ABANDON"
    heartbeat_timeout    = 600 # AWS default is 3600
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
  }, lookup(var.lifecycle_hooks, "terminating", {}))

  # When the SQS queue is enabled, Mufasa doesn't use those Describe* methods
  # which are a source of rate limiting from the AWS API.
  describe_actions = local.sqs_queue_enabled ? [] : [
    "autoscaling:DescribeAutoScalingInstances",
    "autoscaling:DescribeLifecycleHooks",
  ]
}

data "aws_iam_policy_document" "lifecycle_hook" {
  statement {
    effect = "Allow"

    actions = concat(
      [
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:RecordLifecycleActionHeartbeat",
      ],
      local.describe_actions
    )

    # Restrictions using the Auto Scaling Group ARN would create a chicken and egg problem
    # because it is relying on `wait_for_capacity_timeout`.
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/Name"
      values   = [var.name]
    }

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/Stack"
      values   = [var.stack_id]
    }

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/MachineName"
      values   = [var.unique_name]
    }
  }
}

module "policy_name" {
  source = "git@github.com:edgelaboratories/terraform-short-name.git?ref=v0.1.0"

  name          = "${var.unique_name}_lifecycle_hook"
  max_length    = 128
  suffix_length = 4
}

resource "aws_iam_policy" "lifecycle_hook" {
  count = var.lifecycle_hooks.enabled ? 1 : 0

  name   = module.policy_name.name
  policy = data.aws_iam_policy_document.lifecycle_hook.json
}

resource "aws_iam_role_policy_attachment" "lifecycle_hook" {
  count = var.lifecycle_hooks.enabled ? 1 : 0

  role       = var.iam_role_name
  policy_arn = aws_iam_policy.lifecycle_hook[count.index].arn
}

# We configure both initial_lifecycle_hook (in the aws_autoscaling_group resource) and this
# aws_autoscaling_lifecycle_hook resource (with the same values):
#
# * initial_lifecycle_hooks are needed if we want the hooks to be enabled on the instances created at the ASG creation.
#   In order to do that, Terraform creates the ASG with desired/min/max capacities set to 0, creates the hook, then
#   updates the capacities to the configured values.
#   If we configure only an aws_autoscaling_lifecycle_hook resource, there could be a race condition where the first instances of the ASG may be created before the hooks are created by Terraform.
#   In that case, they won't be able to be verified by Mufasa.
#
# * aws_autoscaling_lifecycle_hook is needed if we want to instanciate this module with enable_lifecycle
#   set to false and enable it in a second time. initial_lifecycle_hook does not support update (the Terraform diff
#   shows that the block will be added but it does nothing actually...)
#
resource "aws_autoscaling_lifecycle_hook" "launching" {
  count = var.lifecycle_hooks.enabled ? 1 : 0

  name                   = local.launching_hook.name
  autoscaling_group_name = aws_autoscaling_group.this.name
  default_result         = local.launching_hook.default_result
  heartbeat_timeout      = local.launching_hook.heartbeat_timeout
  lifecycle_transition   = local.launching_hook.lifecycle_transition

  notification_target_arn = local.notification_target_arn
  role_arn                = local.role_arn
}

resource "aws_autoscaling_lifecycle_hook" "terminating" {
  count = var.lifecycle_hooks.enabled ? 1 : 0

  name                   = local.terminating_hook.name
  autoscaling_group_name = aws_autoscaling_group.this.name
  default_result         = local.terminating_hook.default_result
  heartbeat_timeout      = local.terminating_hook.heartbeat_timeout
  lifecycle_transition   = local.terminating_hook.lifecycle_transition

  notification_target_arn = local.notification_target_arn
  role_arn                = local.role_arn
}
