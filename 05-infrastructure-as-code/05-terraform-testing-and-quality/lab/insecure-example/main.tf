# FOR STATIC SCANNING ONLY — do NOT run `terraform apply` here.
#
# This file is deliberately insecure so that `tfsec .` and `checkov -d .` have
# something to flag. tfsec/Checkov parse HCL statically, so no cloud account,
# credentials, or `init` are required to scan it — and nothing is ever created.
#
# Expected findings include: a security group open to the world (0.0.0.0/0) and a
# storage bucket without encryption. Fixing them is a stretch goal in the lab.

resource "aws_security_group" "open" {
  name        = "wide-open"
  description = "Intentionally insecure for scanning demos"

  ingress {
    description = "SSH from anywhere — tfsec will flag this"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "unencrypted" {
  bucket = "example-insecure-unencrypted-bucket"
}
