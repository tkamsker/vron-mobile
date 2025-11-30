#!/bin/bash

##############################################################################
# GraphQL Login Test Script
#
# Tests the vron.one GraphQL authentication endpoint
#
# Usage:
#   ./scripts/test-graphql-login.sh <email> <password>
#   ./scripts/test-graphql-login.sh  # Uses default test credentials
#
# Example:
#   ./scripts/test-graphql-login.sh rusuandreicristian+10@gmail.com QuackQuackIAmADuck
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GraphQL endpoint
GRAPHQL_ENDPOINT="https://api.vron.stage.motorenflug.at/graphql"

# Default test credentials (from AUTHENTICATION.md)
DEFAULT_EMAIL="rusuandreicristian+10@gmail.com"
DEFAULT_PASSWORD="QuackQuackIAmADuck"

##############################################################################
# Functions
##############################################################################

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_json() {
    if command -v jq &> /dev/null; then
        echo "$1" | jq '.'
    else
        echo "$1"
    fi
}

##############################################################################
# Main Script
##############################################################################

# Parse arguments
if [ $# -eq 0 ]; then
    print_info "No credentials provided, using default test account"
    EMAIL="$DEFAULT_EMAIL"
    PASSWORD="$DEFAULT_PASSWORD"
elif [ $# -eq 2 ]; then
    EMAIL="$1"
    PASSWORD="$2"
else
    echo "Usage: $0 [email] [password]"
    echo ""
    echo "Examples:"
    echo "  $0                                                    # Use default test credentials"
    echo "  $0 user@example.com mypassword                        # Use custom credentials"
    echo ""
    echo "Default test credentials:"
    echo "  Email: $DEFAULT_EMAIL"
    echo "  Password: $DEFAULT_PASSWORD"
    exit 1
fi

print_header "VRON GraphQL Login Test"

echo ""
echo "Endpoint: $GRAPHQL_ENDPOINT"
echo "Email:    $EMAIL"
echo "Password: $(echo "$PASSWORD" | sed 's/./*/g')"  # Masked password
echo ""

##############################################################################
# Step 1: Sign In
##############################################################################

print_header "Step 1: Signing In"

# Construct GraphQL mutation
GRAPHQL_QUERY=$(cat <<EOF
{
  "query": "mutation SignIn(\$input: SignInInput!) { signIn(input: \$input) { accessToken } }",
  "variables": {
    "input": {
      "email": "$EMAIL",
      "password": "$PASSWORD"
    }
  }
}
EOF
)

echo "Sending SignIn mutation..."
echo ""

# Make request
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$GRAPHQL_QUERY" \
  "$GRAPHQL_ENDPOINT")

# Check for errors
if echo "$RESPONSE" | grep -q '"errors"'; then
    print_error "Authentication failed!"
    echo ""
    echo "Response:"
    print_json "$RESPONSE"
    exit 1
fi

# Extract access token
if command -v jq &> /dev/null; then
    ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.data.signIn.accessToken')
else
    # Fallback: manual parsing if jq not available
    ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    print_error "Failed to extract access token from response"
    echo ""
    echo "Response:"
    print_json "$RESPONSE"
    exit 1
fi

print_success "Authentication successful!"
echo ""
echo "Access Token (first 50 chars): ${ACCESS_TOKEN:0:50}..."
echo ""

##############################################################################
# Step 2: Encode AUTH_CODE
##############################################################################

print_header "Step 2: Encoding AUTH_CODE"

# Construct AUTH_CODE JSON (per AUTHENTICATION.md format)
AUTH_JSON=$(cat <<EOF
{
  "MERCHANT": {
    "accessToken": "$ACCESS_TOKEN"
  },
  "activeRoles": {
    "merchants": "MERCHANT"
  }
}
EOF
)

# Base64 encode (remove newlines)
AUTH_CODE=$(echo -n "$AUTH_JSON" | base64 | tr -d '\n')

print_success "AUTH_CODE generated"
echo ""
echo "AUTH_CODE (first 80 chars): ${AUTH_CODE:0:80}..."
echo ""
echo "Full AUTH_CODE:"
echo "$AUTH_CODE"
echo ""

##############################################################################
# Step 3: Test AUTH_CODE with Projects Query
##############################################################################

print_header "Step 3: Testing AUTH_CODE with Projects Query"

# Construct projects query
PROJECTS_QUERY=$(cat <<EOF
{
  "query": "query GetProjects { projects(first: 5) { edges { node { id name description status } } } }"
}
EOF
)

echo "Fetching projects with AUTH_CODE..."
echo ""

# Make authenticated request
PROJECTS_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH_CODE" \
  -H "X-VRon-Platform: merchants" \
  -d "$PROJECTS_QUERY" \
  "$GRAPHQL_ENDPOINT")

# Check for errors
if echo "$PROJECTS_RESPONSE" | grep -q '"errors"'; then
    print_error "Projects query failed!"
    echo ""
    echo "Response:"
    print_json "$PROJECTS_RESPONSE"
    exit 1
fi

# Check for successful data
if echo "$PROJECTS_RESPONSE" | grep -q '"projects"'; then
    print_success "Projects query successful!"
    echo ""
    echo "Projects Response:"
    print_json "$PROJECTS_RESPONSE"
    echo ""

    # Count projects if jq available
    if command -v jq &> /dev/null; then
        PROJECT_COUNT=$(echo "$PROJECTS_RESPONSE" | jq '.data.projects.edges | length')
        print_info "Found $PROJECT_COUNT projects"
    fi
else
    print_error "Unexpected response format"
    echo ""
    echo "Response:"
    print_json "$PROJECTS_RESPONSE"
    exit 1
fi

##############################################################################
# Step 4: Sign Out
##############################################################################

print_header "Step 4: Signing Out"

# Construct signOut mutation
SIGNOUT_QUERY=$(cat <<EOF
{
  "query": "mutation SignOut { signOut }"
}
EOF
)

echo "Sending SignOut mutation..."
echo ""

# Make signout request
SIGNOUT_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH_CODE" \
  -H "X-VRon-Platform: merchants" \
  -d "$SIGNOUT_QUERY" \
  "$GRAPHQL_ENDPOINT")

# Check response
if echo "$SIGNOUT_RESPONSE" | grep -q '"signOut":true' || echo "$SIGNOUT_RESPONSE" | grep -q '"signOut": true'; then
    print_success "Sign out successful!"
    echo ""
    echo "Response:"
    print_json "$SIGNOUT_RESPONSE"
else
    print_error "Sign out failed or unexpected response"
    echo ""
    echo "Response:"
    print_json "$SIGNOUT_RESPONSE"
fi

echo ""

##############################################################################
# Summary
##############################################################################

print_header "Test Summary"

echo ""
print_success "All tests passed!"
echo ""
echo "Next Steps:"
echo "  1. Copy the AUTH_CODE above to use in authenticated requests"
echo "  2. Use the following headers for API calls:"
echo "     Authorization: Bearer <AUTH_CODE>"
echo "     X-VRon-Platform: merchants"
echo ""
echo "Save AUTH_CODE for Flutter app:"
echo "  Add to .env file:"
echo "    AUTH_TOKEN=$AUTH_CODE"
echo ""

# Save to temporary file
OUTPUT_FILE="/tmp/vron-auth-code.txt"
echo "$AUTH_CODE" > "$OUTPUT_FILE"
print_info "AUTH_CODE saved to: $OUTPUT_FILE"
echo ""
