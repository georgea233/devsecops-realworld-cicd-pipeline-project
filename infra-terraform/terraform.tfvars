aws_region            = "us-east-2"
iam_role_name         = "AWS-EC2-Administrator-Role"
instance_profile_name = "AWS-EC2FullAccess-Profile"
instance_name         = "Jenkins-CI"
instance_type         = "t2.large"
security_group_name   = "DevSecOps-Jenkins-CI-SG"
key_name              = "ohio-keypair"
ingress_rules = [{
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
  },
  {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]

