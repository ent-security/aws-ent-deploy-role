terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # aws_rolesanywhere_trust_anchor / _profile were added in the AWS provider 4.51.0;
      # require 5.x for the current resource schema.
      version = ">= 5.0.0"
    }
  }
}
