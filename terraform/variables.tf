variable "aws_region" {
  description = "AWS bölgesi"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance tipi"
  type        = string
  default     = "t3.large"
}