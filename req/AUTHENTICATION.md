## API Endpoint for development : https://api.vron.stage.motorenflug.at/graphql

### Mutation for signing in:

```graphql
mutation SignIn($input: SignInInput!) {
  signIn(input: $input) {
    accessToken
  }
}
```

### When sending a request to the API, ensure you include the following headers:

```http
Authorization: "Bearer <AUTH_CODE>"
X-VRon-Platform: "merchants"
```

### The AUTH_CODE is a base64 encoded string of the following format:

```
{
    "MERCHANT": {
        "accessToken": <ACCESS_TOKEN_FROM_SIGN_IN_RESPONSE>
    },

    "activeRoles": {
        "merchants":"MERCHANT"
    }
}
```

### For signing out:

```graphql
mutation SignOut {
  signOut
}
```

### Ensure you include the same headers as above when signing out.

### You can use the following e-mail / password for testing:

```json
{
  "email": "rusuandreicristian+10@gmail.com",
  "password": "QuackQuackIAmADuck"
}
```

### Or, create an account here:

https://app.vron.stage.motorenflug.at/en/auth/sign-up
