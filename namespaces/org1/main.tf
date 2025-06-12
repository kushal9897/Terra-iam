module "team_a" {
  source        = "./modules"
  ami           = var.ami
  instance_type = "t2.micro"
  name          = "team-a-instance"
  team          = "team-a"
}