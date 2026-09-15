variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "eks-service-mesh-cluster"
}

variable "cluster_version" {
  type    = string
  default = "1.32"
}