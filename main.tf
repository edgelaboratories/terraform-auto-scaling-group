locals {
  mufasa = merge(
    {
      enabled   = var.lifecycle_hooks.enabled
      sqs_queue = local.sqs_queue_enabled ? module.queue[0].queue_name : null

      # FIXME: this should be separated
      heartbeat_timeout = min(local.launching_hook.heartbeat_timeout, local.terminating_hook.heartbeat_timeout)
    },
    var.mufasa
  )

  parts = concat(
    [
      {
        filename     = "/etc/mufasa/config.yml"
        content_type = "application/yaml"
        content = yamlencode({
          mufasa = local.mufasa
        })
      }
    ],
    var.cloud_init_parts
  )
}

data "cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false

  dynamic "part" {
    for_each = local.parts
    content {
      filename     = part.value["filename"]
      content_type = lookup(part.value, "content_type", "text/cloud-config")
      content      = part.value["content"]

      # By default:
      # * append lists to each other
      # * recursively merge dict contents together, and append list values
      # * concatenate strings together
      # See: https://cloudinit.readthedocs.io/en/latest/topics/merging.html
      merge_type = lookup(part.value, "merge_type", "list(append)+dict(no_replace,recurse_list)+str(append)")
    }
  }
}

# Consul still need the non-token metadata accesses.
# tfsec:ignore:aws-autoscaling-enforce-http-token-imds
resource "aws_launch_configuration" "this" {
  name_prefix          = var.name_prefix
  image_id             = var.image_id
  instance_type        = var.instance_type
  user_data            = data.cloudinit_config.user_data.rendered
  iam_instance_profile = var.iam_instance_profile

  key_name = var.key_name

  security_groups = var.security_group_ids

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    encrypted = true
  }
}

resource "aws_autoscaling_group" "this" {
  name                 = var.unique_name
  launch_configuration = aws_launch_configuration.this.name

  min_size              = var.min_size
  max_size              = var.max_size
  desired_capacity      = var.desired_capacity
  max_instance_lifetime = var.max_instance_lifetime

  vpc_zone_identifier = var.subnet_ids

  target_group_arns = local.target_group_arns
  health_check_type = "ELB"

  # This grace period is only applicable when the instance is InService, hence it's deactivated when using the lifecycle hooks.
  # XXX 0 is seen as null, hence the 1. https://github.com/hashicorp/terraform-provider-aws/issues/4981
  health_check_grace_period = var.lifecycle_hooks.enabled ? 1 : var.health_check_grace_period

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  lifecycle {
    create_before_destroy = true
  }

  wait_for_capacity_timeout = var.wait_for_capacity_timeout

  # We use dynamic for initial_lifecycle_hook so it can be enable/disable based on enablelifecycle variable
  dynamic "initial_lifecycle_hook" {
    for_each = var.lifecycle_hooks.enabled ? [local.launching_hook, local.terminating_hook] : []

    # see aws_autoscaling_lifecycle_hook resource in lifecycle.tf for more explanation about this lifecycle hook.
    content {
      name                 = initial_lifecycle_hook.value.name
      default_result       = initial_lifecycle_hook.value.default_result
      heartbeat_timeout    = initial_lifecycle_hook.value.heartbeat_timeout
      lifecycle_transition = initial_lifecycle_hook.value.lifecycle_transition

      # see queue.tf
      notification_target_arn = local.notification_target_arn
      role_arn                = local.role_arn
    }
  }

  dynamic "instance_refresh" {
    for_each = var.auto_instance_refresh ? [{}] : []

    # It changes the instances in two batches: a fifth, one hour later the remaining ones.
    content {
      strategy = "Rolling"
      preferences {
        checkpoint_delay       = var.instance_refresh_checkpoint_delay
        checkpoint_percentages = var.instance_refresh_checkpoint_percentages
        min_healthy_percentage = 90
      }
      triggers = []
    }
  }

  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }

  tag {
    key                 = "MachineName"
    value               = var.unique_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Stack"
    value               = var.stack_id
    propagate_at_launch = true
  }

  tag {
    key                 = "Managed"
    value               = "terraform"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.value.key
      value               = tag.value.value
      propagate_at_launch = tag.value.propagate_at_launch
    }
  }
}
