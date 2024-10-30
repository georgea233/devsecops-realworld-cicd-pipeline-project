terraform {
  backend "s3" {
    bucket = "ec2-builder-remote-state"
    key    = "ec2-image-builder/state.tfstate"
    region = "us-east-2"

    # Replace this with your DynamoDB table name!
    dynamodb_table = "anslem-terraform-tf-state-lock"
  }
}
 
