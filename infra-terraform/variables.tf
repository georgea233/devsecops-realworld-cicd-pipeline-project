variable "aws_region" {
  description = "The AWS region to deploy the resources"
  type        = string
  default     = "us-east-2"
}

# variable "profile" {
#   description = "The AWS profile to use"
#   type        = string
#   default     = "george"
# }

## IAM role for Jenkins CI
variable "iam_role_name" {
  description = "Name of the IAM role for Jenkins CI"
  default     = "AWS-EC2-Administrator-Role"
}

variable "instance_profile_name" {
  description = "Name of the instance profile for Jenkins CI"
  default     = "AWS-EC2FullAccess-Profile"
}

variable "instance_name" {
  description = "Name of the Jenkins CI instance"
  default     = "Jenkins-CI"
}
variable "instance_type" {
  description = "Instance type for the Jenkins CI instance"
  default     = "t2.xlarge"
}

variable "key_name" {
  description = "Key pair name for SSH access"
  default     = "ohio-keypair"
}

variable "security_group_name" {
  description = "Name of the security group for Jenkins CI"
  default     = "DevSecOps-Jenkins-CI-SG"
}

data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

variable "ingress_rules" {
  description = "List of ingress rules for the security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 9000
      to_port     = 9000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
