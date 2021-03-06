locals {
  target_group_enabled = var.target_group.port > 0

  target_group_arns = concat(
    var.target_group_arns,
    local.target_group_enabled == true ? [aws_lb_target_group.this[0].arn] : []
  )
}

module "target_group" {
  count = local.target_group_enabled == true ? 1 : 0

  source = "git@github.com:edgelaboratories/terraform-short-name.git?ref=v0.1.0"

  # The name must be <=32 characters, contain only alphadigit+hyphens, and not end with "-".
  name          = var.unique_name
  max_length    = 32
  suffix_length = 4
}

resource "aws_lb_target_group" "this" {
  count = local.target_group_enabled == true ? 1 : 0

  name     = module.target_group[0].name
  port     = var.target_group.port
  protocol = var.target_group.protocol
  vpc_id   = var.vpc_id

  # If mufasa is enabled, it answers the health_check otherwise, consul does it.
  dynamic "health_check" {
    for_each = local.mufasa.enabled ? [{ path = "/healthy", port = 9876 }] : [{ path = "/v1/status/leader", port = 8500 }]

    content {
      protocol = "HTTP"
      path     = health_check.value.path
      port     = health_check.value.port
      matcher  = "200"

      interval            = var.health_check.interval
      timeout             = var.health_check.timeout
      healthy_threshold   = var.health_check.healthy_threshold
      unhealthy_threshold = var.health_check.unhealthy_threshold
    }
  }

  tags = {
    MachineName = var.machine_name
    Stack       = var.stack_id
    Managed     = "terraform"
  }
}
