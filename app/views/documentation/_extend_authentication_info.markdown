Some notes on OAUTH and the Index. Will go into swagger docs

# Authentication on the Bike Index

We use OAuth2. Every request must be authenticated.

There are two supported ways of authenticating with the Bike Index through OAuth2:

1. Authorization flow (also called Explicit grant flow)

2. Client-side flow (also called Implicit grant flow)

The Authorization flow enables long lived access through refresh tokens (instead of logging out the user every hour), is more secure, and is generally what you should be using. Learn more about [Authorization flow in OAuth2](http://labs.hybris.com/2012/06/01/oauth2-authorization-code-flow/).

The Client-side flow is good for client-side javascript apps. Here's an article on [Client-side flow in OAuth2](http://labs.hybris.com/2012/06/05/oauth2-the-implicit-flow-aka-as-the-client-side-flow/).

## Authentication params

By default doorkeeper authenticates clients using HTTP Basic authentication scheme. If the basic auth is not found in the authorization header, then it falls back to post parameters (client_id and client_secret).

For example, this would be the HTTP request for Client Credentials flow, using basic auth:

    POST /oauth/token
    Authorization: Basic czZCaGRSa3F0MzpnWDFmQmF0M2JW
    grant_type=client_credentials

You have the option to include the client credentials using the request body instead of using HTTP Basic.

    POST /oauth/token
    grant_type=client_credentials&client_id=...&client_secret=...

Putting them in the parameters is useful for browser-based exploration of the API

    #{ENV['BASE_URL']}api/v1/users/current?access_token=lksafdlsadfl;jkafsdl;jkasdfasdf
    


(managed by doorkeeper [reference](https://github.com/doorkeeper-gem/doorkeeper/wiki/Changing-how-clients-are-authenticated))


## Review applications you've granted access

[/oauth/authorized_applications](/oauth/authorized_applications)

## OAuth refresh tokens


in ruby: 

```ruby
client = OAuth2::Client.new('app_id', 'app_secret', site: "#{['base_url']}")
puts client.auth_code.authorize_url(:redirect_uri => 'urn:ietf:wg:oauth:2.0:oob')
# Vist the URL that is printed out and authenticate.
# You will be sent to a page that shows you the access code, (because the redirect_uri is the one used for testing).
token = client.auth_code.get_token(code, :redirect_uri => 'urn:ietf:wg:oauth:2.0:oob')
# Where "code" is the code from the page after authentication
# Bike Index tokens expire in 1 hour - (but that is subject to change without notice)

token.expired?
# => false

# If your token has expired, you will get this:
token.expired?
# => true

# And you can refresh your token with 
new_token = token.refresh!
```

You will get a refresh token back when you create a token. So long as you have that token, you can create a new token when your existing token has expired.

## Authorization flow

### Registering the client

Once you have doorkeeper up and running, set up a new client in `/oauth/applications/new`. For testing proposes, you should fill in the redirect URI field with `urn:ietf:wg:oauth:2.0:oob`. This will tell doorkeeper to display the authorization code instead of redirecting to a client application (that you don't have now).

You can change this behaviour by changing the `test_redirect_uri` config in the doorkeeper initializer.

### Requesting authorization

To request the authorization token, you should visit the `/oauth/authorize` endpoint. You can do that either by clicking in the link to the authorization page in the app details or by visiting manually the URL:

```
http://localhost:3000/oauth/authorize?client_id=YOUR_CLIENT_ID&redirect_uri=urn:ietf:wg:oauth:2.0:oob&response_type=code
```

Once you are there, you should sign in and click on `Authorize`. You'll see this page:

![gpoy](https://www.evernote.com/shard/s57/sh/6194cd58-ec90-4712-89a2-ca94d64aa918/2da49bed7503838fa03866e232a95bc2/res/b2ea7a22-cf97-4709-9a09-8c2e68522cd4/skitch.png)

### Requesting the access token

To request the access token, you should use the returned code and exchange it for an access token. To do that you can use any HTTP client. In this case, I used `rest-client`:

```ruby
parameters = 'client_id=THE_ID&client_secret=THE_SECRET&code=RETURNED_CODE&grant_type=authorization_code&redirect_uri=urn:ietf:wg:oauth:2.0:oob'
RestClient.post 'http://localhost:3000/oauth/token', parameters

# The response will be
{
 "access_token": "de6780bc506a0446309bd9362820ba8aed28aa506c71eedbe1c5c4f9dd350e54",
 "token_type": "bearer", 
 "expires_in": 7200,
 "refresh_token": "8257e65c97202ed1726cf9571600918f3bffb2544b26e00a61df9897668c33a1"
}
```

You can now make requests to the API with the access token returned.




---

### Client credentials flow
The `Client Credentials` flow is probably the most simple flow of OAuth 2 flows. The main difference from the others is that this flow is not associated with a resource owner.

One usage of this flow would be retrieving client statistics for example. Since the access token would be connected to the client only, the access token won't have access to private user data for example.

### Usage

To get an access token from client credentials flow, you have to do a `post` to `/oauth/token` endpoint:

    POST /oauth/token
    Authorization: Basic czZCaGRSa3F0MzpnWDFmQmF0M2JW
    Content-Type: application/x-www-form-urlencoded;charset=UTF-8
    grant_type=client_credentials

The Authorization header includes the encoded credentials for the client. For more information and options on how authenticate clients, check [this page in the wiki](Changing-how-clients-are-authenticated).

In ruby, it would be something like this:

```ruby
require 'rest-client'
require 'json'

client_id = '4ea1b...'
client_secret = 'a2982...'

response = RestClient.post 'http://localhost:3000/oauth/token', {
  grant_type: 'client_credentials',
  client_id: client_id,
  client_secret: client_secret
}
```

Notice that in this case we used client_id/secret on parameters instead of using the encoded header.

After that you'll have the access token in the response:

```ruby
token = JSON.parse(response)["access_token"]
# => 'a2982...'
```

And then, you can request access to protected resources that do not require a resource owner:

```ruby
RestClient.get 'http://localhost:3000/api/v1/profiles.json', { 'Authorization' => "Bearer #{token}" }
# => "[{"email":"tara_kertzmann@yundt.name","id":25,"name":"Jorge Ward","username":"leonor"}, ...]"
```

(managed by doorkeeper [reference](https://github.com/doorkeeper-gem/doorkeeper/wiki/Client-Credentials-flow))