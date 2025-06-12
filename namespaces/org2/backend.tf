terraform {
  backend "s3" {
    bucket = "tfff-kushal "
    key    = "env/dev/terraform.tfstate"
    region = "us-east-1"
  }
}
