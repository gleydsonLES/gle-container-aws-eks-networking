variable "project_name" {
  description = "Project name used for tagging"
  type        = string
}

variable "vpc_cidr" {
  description = "Primary VPC CIDR"
  type        = string
}

variable "vpc_additional_cidrs" {
  description = "Additional VPC CIDRs"
  type        = list(string)
  default     = []
}

variable "public_subnets" {
  description = "List of public subnets to create"
  type = list(object({
    name              = string
    cidr              = string
    availability_zone = string
  }))
}

variable "private_subnets" {
  description = "List of private subnets to create"
  type = list(object({
    name              = string
    cidr              = string
    availability_zone = string
  }))
}

variable "database_subnets" {
  description = "List of database subnets to create"
  type = list(object({
    name              = string
    cidr              = string
    availability_zone = string
  }))
  default = []
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
