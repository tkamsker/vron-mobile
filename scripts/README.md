# VRON Mobile Scripts

Utility scripts for testing and development.

## GraphQL Authentication Test Scripts

### 1. Full Test Script: `test-graphql-login.sh`

Comprehensive test that validates the complete authentication flow:
- ✓ Sign in with credentials
- ✓ Encode AUTH_CODE in required base64 format
- ✓ Test authenticated request (fetch projects)
- ✓ Sign out

**Usage:**

```bash
# Use default test credentials
./scripts/test-graphql-login.sh

# Use custom credentials
./scripts/test-graphql-login.sh user@example.com mypassword
```

**Features:**
- Colored output for easy reading
- JSON pretty-printing (if `jq` installed)
- Saves AUTH_CODE to `/tmp/vron-auth-code.txt`
- Complete error handling

**Example Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VRON GraphQL Login Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Endpoint: https://api.vron.stage.motorenflug.at/graphql
Email:    user@example.com
Password: ******************

✓ Authentication successful!
✓ AUTH_CODE generated
✓ Projects query successful!
✓ Sign out successful!
```

---

### 2. Simple Test Script: `test-login-simple.sh`

Quick login test without extra features:
- ✓ Sign in with credentials
- ✓ Display access token and AUTH_CODE
- ✓ Minimal output

**Usage:**

```bash
./scripts/test-login-simple.sh user@example.com mypassword
```

**Example Output:**
```
Testing login to: https://api.vron.stage.motorenflug.at/graphql
Email: user@example.com

Sending request...

Response:
{
  "data": {
    "signIn": {
      "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
  }
}

✓ Login successful!

Access Token:
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

AUTH_CODE (for Flutter app):
eyJNRVJDSEFOVCI6eyJhY2Nlc3NUb2tlbiI6ImV5SmhiR2NpT2lKSVV6STFOaUlzSW5SNWND...

Use in API requests with headers:
  Authorization: Bearer eyJNRVJDSEFOVCI6eyJhY2Nlc3NUb2tlbiI6ImV5SmhiR2...
  X-VRon-Platform: merchants
```

---

## Prerequisites

**Required:**
- `curl` - for making HTTP requests
- `base64` - for encoding AUTH_CODE

**Optional (for better output):**
- `jq` - for JSON pretty-printing
  ```bash
  # Install on macOS
  brew install jq

  # Install on Ubuntu/Debian
  sudo apt-get install jq
  ```

---

## Test Credentials

From `req/AUTHENTICATION.md`:

```json
{
  "email": "rusuandreicristian+10@gmail.com",
  "password": "QuackQuackIAmADuck"
}
```

**Note**: If the default test account doesn't work, create a new account at:
https://app.vron.stage.motorenflug.at/en/auth/sign-up

---

## GraphQL API Details

**Endpoint:**
```
https://api.vron.stage.motorenflug.at/graphql
```

**Required Headers:**
```http
Content-Type: application/json
Authorization: Bearer <AUTH_CODE>
X-VRon-Platform: merchants
```

**AUTH_CODE Format:**

Base64-encoded JSON:
```json
{
  "MERCHANT": {
    "accessToken": "<ACCESS_TOKEN_FROM_SIGN_IN>"
  },
  "activeRoles": {
    "merchants": "MERCHANT"
  }
}
```

---

## Common Issues

### 1. "User not found" Error

**Solution**: The test account may have expired. Create a new account at:
https://app.vron.stage.motorenflug.at/en/auth/sign-up

Then test with your new credentials:
```bash
./scripts/test-login-simple.sh your-email@example.com yourpassword
```

### 2. "Command not found: jq"

**Solution**: The scripts work without `jq`, but output won't be pretty-printed. Install `jq` for better formatting:
```bash
brew install jq  # macOS
```

### 3. "Permission denied"

**Solution**: Make the scripts executable:
```bash
chmod +x scripts/test-graphql-login.sh
chmod +x scripts/test-login-simple.sh
```

### 4. Network/SSL Errors

**Solution**: Check your internet connection and verify the endpoint is accessible:
```bash
curl -I https://api.vron.stage.motorenflug.at/graphql
```

---

## Using AUTH_CODE in Flutter

After running the test script, copy the AUTH_CODE and use it in your Flutter app:

**1. Add to `.env` file:**
```bash
AUTH_TOKEN=eyJNRVJDSEFOVCI6eyJhY2Nlc3NUb2tlbiI6ImV5SmhiR2NpT2lKSVV6STFOaUlzSW5SNWND...
```

**2. Use in GraphQL requests:**
```dart
final authCode = dotenv.env['AUTH_TOKEN'];

final httpLink = HttpLink('https://api.vron.stage.motorenflug.at/graphql');
final authLink = AuthLink(
  getToken: () async => 'Bearer $authCode',
);

final client = GraphQLClient(
  link: authLink.concat(httpLink),
  cache: GraphQLCache(),
  defaultPolicies: DefaultPolicies(
    query: Policies(fetch: FetchPolicy.cacheFirst),
  ),
);
```

**3. Add required header:**
```dart
final link = Link.from([
  AuthLink(getToken: () async => 'Bearer $authCode'),
  HttpLink(
    'https://api.vron.stage.motorenflug.at/graphql',
    defaultHeaders: {
      'X-VRon-Platform': 'merchants',
    },
  ),
]);
```

---

## Manual Testing with cURL

**Sign In:**
```bash
curl -X POST https://api.vron.stage.motorenflug.at/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation SignIn($input: SignInInput!) { signIn(input: $input) { accessToken } }",
    "variables": {
      "input": {
        "email": "user@example.com",
        "password": "yourpassword"
      }
    }
  }'
```

**Fetch Projects (authenticated):**
```bash
curl -X POST https://api.vron.stage.motorenflug.at/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <AUTH_CODE>" \
  -H "X-VRon-Platform: merchants" \
  -d '{
    "query": "query { projects(first: 5) { edges { node { id name } } } }"
  }'
```

---

## Additional Resources

- [GraphQL Schema](../specs/001-vron-mobile-companion/contracts/graphql-schema.graphql)
- [Authentication Documentation](../req/AUTHENTICATION.md)
- [Platform Channel Contracts](../specs/001-vron-mobile-companion/contracts/platform-channels.md)
- [Feature Specification](../specs/001-vron-mobile-companion/spec.md)
