module "team_b" {
  source        = "../../modules"
  ami           = var.ami
  instance_type = "t2.micro"
  name          = "team-b-instance"
  team          = "team-b"
}