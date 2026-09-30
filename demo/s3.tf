# -----------------------------------------------------------------------------
# S3
# -----------------------------------------------------------------------------
/*
resource "aws_s3_bucket" "main" {
  bucket = "team-alpha-mupando-dev"

  tags = {
    Name = "team-alpha-mupando-dev"
  }
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
*/