variable "stack_id" {}

variable "name" {}

variable "machine_name" {}

variable "unique_name" {}

variable "vpc_id" {}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "name_prefix" {}

variable "key_name" {}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "desired_capacity" {
  type = number
}

variable "instance_type" {}

variable "image_id" {}

variable "user_data" {
  description = "Cloud-init content"
}

variable "iam_instance_profile" {}

variable "iam_role_name" {}

variable "max_instance_lifetime" {
  default     = 0
  description = <<EOF
The maximum amount of time, in seconds, that an instance can be in service.

0 unconfigures the previously configured maximum instance lifetime.
Otherwise, the value must be greater than or equal to 86400 (1 day).

See: https://docs.aws.amazon.com/autoscaling/ec2/userguide/asg-max-instance-lifetime.html
EOF
}

variable "tags" {
  type = list(object({
    key                 = string
    value               = string
    propagate_at_launch = bool
  }))

  default = []
}

variable "lifecycle_hooks" {
  default = {
    enabled     = false
    sqs_enabled = false
  }
  description = <<EOF
Configuration for the lifecycle hooks of the AutoScalingGroup. Here is a full example of the available options which shows the default values.

The autoscaling group will wait up to heartbeat_timeout seconds for the instance to notify using CompleteLifecycleAction
that is terminated correctly, or ask for more time up to 100 · heartbeat_timeout (max. 48h.)
If the autoscaling group didn't get the notification, the ABANDON will terminate the instance.

    lifecycle_hooks = {
      enabled     = true
      sqs_enabled = true

      launching = {
        name              = "launching"
        heartbeat_timeout = 600
        default_result    = "ABANDON"
      }

      terminating = {
        name              = "terminating"
        heartbeat_timeout = 600
        default_result    = "ABANDON"
      }
    }
EOF
}

variable "mufasa" {
  default = {
    logging_level = "INFO"
  }

  description = <<EOF
Configuration for Mufasa, provide a S3 bucket to get failure reports.

    mufasa = {
      report_bucket = <name of the s3 bucket>
      logging_level = "DEBUG"
    }

EOF
}

variable "target_group" {
  type = object({
    port = number
  })

  default = {
    port = -1
  }
}

variable "health_check" {
  type = object({
    interval            = number
    timeout             = number
    healthy_threshold   = number
    unhealthy_threshold = number
  })

  description = <<EOF
Configuration for the HTTP health checks.

Interval and timeout are managing the health checks themselves. The thresholds are counters requiring n consecutive results to consider a change in state.
EOF
}

variable "wait_for_capacity_timeout" {
  # https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html#wait_for_capacity_timeout
  description = <<EOF
A maximum duration that Terraform should wait for ASG instances to be healthy before timing out
Setting this to "0" causes Terraform to skip all Capacity Waiting behavior.
EOF
  default     = "10m"
}

variable "health_check_grace_period" {
  description = <<EOF
When an instance launches, Amazon EC2 Auto Scaling uses the value of the HealthCheckGracePeriod for the Auto Scaling group to determine how long to wait before checking the health status of the instance. Amazon EC2 and Elastic Load Balancing health checks can complete before the health check grace period expires. However, Amazon EC2 Auto Scaling does not act on them until the health check grace period expires.

**NB** this value is not used when the lifecycle hooks are enabled.
EOF
  default     = 300 # AWS default value
}
