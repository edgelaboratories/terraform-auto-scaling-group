variable "unique_name" {
  description = "A unique, short name that will be used to create the queue"
  type        = string
}

variable "pretty_name" {
  description = "A free text pretty name to describe the queue"
  type        = string
}

variable "retention_period" {
  description = "The TTL for the SQS messages, in seconds"
  type        = number
}

variable "stack_id" {
  description = "The Stack ID"
  type        = string
}

variable "attach_to_role" {
  description = "The name of the role to attach policies to."
  type        = string
}
