#!/usr/bin/env bash
# Creates the S3 bucket used to store Terraform state, if it doesn't already exist.
# Run this once before `terraform init`.
#
# Usage: ./tf-state.sh
# Override defaults with env vars, e.g. TF_STATE_BUCKET=my-bucket AWS_REGION=eu-west-1 ./tf-state.sh

set -euo pipefail

BUCKET="${TF_STATE_BUCKET:-team-bravo-tfstate}"
REGION="${AWS_REGION:-eu-west-2}"

echo "Checking for state bucket: ${BUCKET} (${REGION})"

if output=$(aws s3api head-bucket --bucket "$BUCKET" 2>&1); then
  echo "Bucket ${BUCKET} already exists - skipping creation."
  exit 0
fi

if echo "$output" | grep -q "403\|Forbidden"; then
  echo "ERROR: Bucket ${BUCKET} exists but is owned by another account (or you lack access)." >&2
  echo "Choose a different name with TF_STATE_BUCKET=<name>." >&2
  exit 1
fi

if ! echo "$output" | grep -q "404\|Not Found"; then
  echo "ERROR: Could not check bucket: ${output}" >&2
  exit 1
fi

echo "Bucket not found - creating ${BUCKET}..."

if [[ "$REGION" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
fi

aws s3api wait bucket-exists --bucket "$BUCKET"

# Keep old state versions so a bad apply can be rolled back
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Bucket ${BUCKET} created with versioning, encryption and public access blocked."
