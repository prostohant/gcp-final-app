variable "project_id" {}

variable "project_number" {}

variable "region" {
  default = "us-central1"
}

variable "zone" {
    default = "us-central1-a"
}
# variable "vpc_name" {
#   default = "custom-training-vpc"
# }

# variable "vpc_ip_range" {
#     default = "10.0.1.0/24"
# }