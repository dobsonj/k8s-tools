
variable "aws_profile" {
  default = "default"
}

variable "region" {
  default = "us-east-2"
}

variable "tag_name" {
  default = "user-dev01"
}

variable "ami" {
  default = "ami-0629230e074c580f2" # ubuntu 20.04 x86_64
}

variable "instance_type" {
  default = "t2.xlarge" # 4x16
}

variable "instance_user" {
  default = "ubuntu"
}

variable "cidr_block" {
  default = "10.0.0.0/16"
}

variable "private_key_file" {
  default = "~/.ssh/id_rsa"
}

variable "public_key_file" {
  default = "~/.ssh/id_rsa.pub"
}

