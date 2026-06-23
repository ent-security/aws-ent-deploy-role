terraform {
  # >= 1.1.0 for moved{} block support (see moved.tf). The AWS provider constraint is unchanged
  # from the pre-refactor root so the commercial path stays byte-for-byte equivalent.
  required_version = ">= 1.1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.1.15"
    }
  }
}
