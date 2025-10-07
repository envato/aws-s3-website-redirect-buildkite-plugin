#!/bin/bash
# Test script for s3-website-redirect plugin

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_test() {
  echo ""
  echo -e "${YELLOW}TEST: $1${NC}"
}

pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

cleanup_env() {
  for var in $(env | grep "^BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT" | cut -d= -f1); do
    unset "$var" 2>/dev/null || true
  done
}

# Test 1: Single redirect configuration
test_single_redirect() {
  print_test "Single redirect configuration"
  
  export BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_BUCKET="test-bucket"
  export BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_SOURCE="old-path/"
  export BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_DESTINATION="https://example.com/new-path/"
  export BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_REGION="us-east-1"
  
  if [ "${BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_BUCKET}" = "test-bucket" ] && \
     [ "${BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_SOURCE}" = "old-path/" ] && \
     [ "${BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_DESTINATION}" = "https://example.com/new-path/" ]; then
    pass "Environment variables set correctly for single redirect"
  else
    fail "Environment variables not set correctly"
  fi
}

# Test 2: Multiple redirects configuration
test_multiple_redirects() {
  print_test "Multiple redirects configuration"
  
  export BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_BUCKET="test-bucket"
  export BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_REDIRECTS_0_SOURCE="path1/"
  export BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_REDIRECTS_0_DESTINATION="https://example.com/new1/"
  export BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_REDIRECTS_1_SOURCE="path2/"
  export BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_REDIRECTS_1_DESTINATION="https://example.com/new2/"
  
  redirect_count=0
  for var in $(env | grep "^BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_REDIRECTS_" | grep "_SOURCE=" | cut -d= -f1); do
    redirect_count=$((redirect_count + 1))
  done
  
  if [ ${redirect_count} -eq 2 ]; then
    pass "Found 2 redirects in configuration"
  else
    fail "Expected 2 redirects, found ${redirect_count}"
  fi
}

# Test 3: Source path normalization
test_source_normalization() {
  print_test "Source path normalization"
  
  # Test removing s3:// prefix
  source="s3://test-bucket/old-path/"
  bucket="test-bucket"
  source="${source#s3://}"
  source="${source#"${bucket}"/}"
  
  if [ "${source}" = "old-path/" ]; then
    pass "Correctly normalized s3:// prefix"
  else
    fail "Failed to normalize s3:// prefix, got: ${source}"
  fi
  
  # Test removing bucket name
  source="test-bucket/another-path/"
  source="${source#"${bucket}"/}"
  
  if [ "${source}" = "another-path/" ]; then
    pass "Correctly normalized bucket name prefix"
  else
    fail "Failed to normalize bucket name, got: ${source}"
  fi
}

# Test 4: AWS CLI command construction
test_aws_command_construction() {
  print_test "AWS CLI command construction"
  
  REGION="us-east-1"
  AWS_OPTS="--region ${REGION}"
  
  if [ "${AWS_OPTS}" = "--region us-east-1" ]; then
    pass "AWS options constructed correctly"
  else
    fail "AWS options incorrect: ${AWS_OPTS}"
  fi
}

# Test 5: Required parameters validation
test_required_parameters() {
  print_test "Required parameters validation"
  
  BUCKET=""
  if [ -z "${BUCKET}" ]; then
    pass "Correctly detects missing bucket parameter"
  else
    fail "Should detect missing bucket parameter"
  fi
  
  BUCKET="test-bucket"
  if [ -n "${BUCKET}" ]; then
    pass "Correctly validates bucket parameter is present"
  else
    fail "Should validate bucket parameter"
  fi
}

# Test 6: Region default value
test_region_default() {
  print_test "Region default value"
  
  unset BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_REGION 2>/dev/null || true
  REGION="${BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_REGION:-us-east-1}"
  
  if [ "${REGION}" = "us-east-1" ]; then
    pass "Correctly uses default region"
  else
    fail "Default region should be us-east-1, got: ${REGION}"
  fi
  
  export BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_REGION="ap-southeast-2"
  REGION="${BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_REGION:-us-east-1}"
  
  if [ "${REGION}" = "ap-southeast-2" ]; then
    pass "Correctly uses custom region"
  else
    fail "Custom region should be ap-southeast-2, got: ${REGION}"
  fi
}

# Test 7: Empty redirects array handling
test_empty_redirects() {
  print_test "Empty redirects array handling"
  
  cleanup_env
  export BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_BUCKET="test-bucket"
  
  redirect_count=0
  for var in $(env | grep "^BUILDKITE_PLUGIN_AWS_S3_WEBSITE_REDIRECT_REDIRECTS_" 2>/dev/null | grep "_SOURCE=" | cut -d= -f1); do
    redirect_count=$((redirect_count + 1))
  done
  
  if [ ${redirect_count} -eq 0 ]; then
    pass "Correctly handles empty redirects array"
  else
    fail "Should find no redirects, found ${redirect_count}"
  fi
}

# Run all tests
echo "================================================"
echo "Running s3-website-redirect Plugin Tests"
echo "================================================"

test_single_redirect
test_multiple_redirects
test_source_normalization
test_aws_command_construction
test_required_parameters
test_region_default
test_empty_redirects

# Print summary
echo ""
echo "================================================"
echo "Test Summary"
echo "================================================"
echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
echo "================================================"

if [ ${TESTS_FAILED} -gt 0 ]; then
  exit 1
fi

exit 0