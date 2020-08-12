# ---------------------------------------------------------------------------------------------------------------------
# environment variables
# define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# aws_access_key_id
# aws_secret_access_key


variable "server_port" {
  description = "the port the server will use for http requests"
  type        = number
  default     = 8080
}

variable "elb_port" {
  description = "the port the elb will use for http requests"
  type        = number
  default     = 80
}