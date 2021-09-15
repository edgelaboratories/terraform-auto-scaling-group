# In case the lifecycle notification are sent to a Queue, the AutoScalingGroup requires
# access to said Queue and its name (obviously)
locals {
  sqs_queue_enabled = lookup(var.lifecycle_hooks, "sqs_enabled", false) && lookup(var.lifecycle_hooks, "enabled", false)

  notification_target_arn = local.sqs_queue_enabled ? module.queue[0].queue_arn : null
  role_arn                = local.sqs_queue_enabled ? module.queue[0].role_lifecycle_management_arn : null
}

module "queue" {
  count = local.sqs_queue_enabled ? 1 : 0

  source = "./queue"

  unique_name = var.unique_name
  pretty_name = "Lifecycle queue for the ASG: ${var.unique_name}"

  stack_id = var.stack_id

  # The messages become useless after the heartbeats time out, in which case SQS
  # will automatically purge them.
  retention_period = min(
    max(
      ceil(max(local.launching_hook.heartbeat_timeout, local.terminating_hook.heartbeat_timeout) * 1.2),
      60 # the min value
    ),
    1209600 # the max value
  )

  attach_to_role = var.iam_role_name
}
