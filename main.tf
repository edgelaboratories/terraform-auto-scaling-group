locals {
  mufasa = merge({
    enabled = var.lifecycle_hooks.enabled
    },
    var.mufasa
  )
}

# Ignore unencrypted root block device.
#tfsec:ignore:AWS014
resource "aws_launch_configuration" "this" {
  name_prefix          = var.name_prefix
  image_id             = var.image_id
  instance_type        = var.instance_type
  user_data            = var.user_data
  iam_instance_profile = var.iam_instance_profile

  key_name = var.key_name

  security_groups = var.security_group_ids

  lifecycle {
    create_before_destroy = true
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

  target_group_arns = local.target_group_enabled == true ? [aws_lb_target_group.this[0].arn] : []
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
