module "team_aa" {
  source        = "./modules"
  ami           = var.ami
  instance_type = "t2.micro"
  name          = "team-a-instance"
  team          = "team-abb"
}