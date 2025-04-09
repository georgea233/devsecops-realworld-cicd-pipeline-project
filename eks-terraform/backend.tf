terraform {
  backend "s3" {
    bucket = "fluentindevops-tf-statefile"
    key    = "fluentindevops-tf-statefile/eks-infra/terraform.tfstate"
    region = "us-east-2"

    # Replace this with your DynamoDB table name!
    use_lockfile = true
  }
}
