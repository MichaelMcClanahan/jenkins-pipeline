variable "region" {
  description = "The AWS region to deploy the cluster in"
  default     = "us-east-2"
}

variable "instance_type" {
  description = "Size of AWS EC2 instance"
  default     = "t2.micro"
}

variable "key_name" {
  description = "Key Pair name for logging into AWS instances"
  default     = "nginx"
}

variable "public_key_path" {
  description = "Public key to use for SSH access"
  default     = "~/.ssh/id_rsa.pub"
}

variable "vpc_cidr" {
  description = "CIDR address for VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR address for the subnet"
  default     = "10.0.1.0/24"
}

variable "subnet_az" {
  description = "Availability zone"
  default     = "us-east-2a"
}
