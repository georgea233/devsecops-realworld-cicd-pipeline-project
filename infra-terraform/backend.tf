terraform {
  backend "s3" {
    bucket = "fluentindevops-remote-state" #fluent-in-devops account
    key    = "fluentindevops/state.tfstate"
    region = "us-east-2"

    # Replace this with your DynamoDB table name!
    dynamodb_table = "devops-terraform-tf-state-lock" #fluent-in-devops account
  }
}

