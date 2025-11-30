#!/bin/bash

##############################################################################
# Simple GraphQL Login Test
#
# Quick test script for vron.one GraphQL authentication
#
# Usage:
#   ./scripts/test-login-simple.sh <email> <password>
##############################################################################

if [ $# -ne 2 ]; then
    echo "Usage: $0 <email> <password>"
    echo ""
    echo "Example:"
    echo "  $0 rusuandreicristian+10@gmail.com QuackQuackIAmADuck"
    exit 1
fi

EMAIL="$1"
PASSWORD="$2"
ENDPOINT="https://api.vron.stage.motorenflug.at/graphql"

echo "Testing login to: $ENDPOINT"
echo "Email: $EMAIL"
echo ""

# GraphQL mutation
QUERY=$(cat <<EOF
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

# Make request
echo "Sending request..."
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$QUERY" \
  "$ENDPOINT")

# Display response
echo ""
echo "Response:"
if command -v jq &> /dev/null; then
    echo "$RESPONSE" | jq '.'
else
    echo "$RESPONSE"
fi

# Extract and encode token if successful
if echo "$RESPONSE" | grep -q '"accessToken"'; then
    echo ""
    echo "✓ Login successful!"

    if command -v jq &> /dev/null; then
        ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.data.signIn.accessToken')

        # Create AUTH_CODE
        AUTH_JSON=$(cat <<EOF
{"MERCHANT":{"accessToken":"$ACCESS_TOKEN"},"activeRoles":{"merchants":"MERCHANT"}}
EOF
)
        AUTH_CODE=$(echo -n "$AUTH_JSON" | base64 | tr -d '\n')

        echo ""
        echo "Access Token:"
        echo "$ACCESS_TOKEN"
        echo ""
        echo "AUTH_CODE (for Flutter app):"
        echo "$AUTH_CODE"
        echo ""
        echo "Use in API requests with headers:"
        echo "  Authorization: Bearer $AUTH_CODE"
        echo "  X-VRon-Platform: merchants"
    fi
else
    echo ""
    echo "✗ Login failed"
fi
