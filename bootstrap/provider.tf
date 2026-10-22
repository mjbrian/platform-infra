provider "aws" {
  region = "us-west-1"
  default_tags {
    tags = {
      project    = "platform-lab"
      owner      = "matthew"
      ttl        = "none"
      managed_by = "terraform"
    }
  }
}
