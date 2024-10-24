resource "aws_iam_role" "jenkins_ci" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_ci" {
  role       = aws_iam_role.jenkins_ci.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = var.instance_profile_name
  role = aws_iam_role.jenkins_ci.name
}


data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "jenkins_ci" {
  name        = var.security_group_name
  vpc_id      = data.aws_vpc.default.id
  description = "DevSecOps-Jenkins-CI-SG"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "jenkins_ci" {
  ami           = data.aws_ami.ubuntu_22_04.id
  instance_type = var.instance_type
  subnet_id     = data.aws_subnets.default.ids[0]
  # subnet_id = element(data.aws_subnets.default.ids, 0)
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.jenkins_instance_profile.name
  vpc_security_group_ids      = [aws_security_group.jenkins_ci.id]
  user_data                   = file("${path.module}/installations.sh")
  associate_public_ip_address = true

  root_block_device {
    volume_size = 50
  }

  tags = {
    Name = var.instance_name
  }
}
