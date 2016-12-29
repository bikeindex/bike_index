<a class="ref" id="ref_oauth">

## OAuth2 - Authentication on Bike Index

The Bike Index uses OAuth2. 

<a class="ref" id="ref_plugins">

###Plugins and external libraries

- **Ruby**: [omniauth-bike-index](https://github.com/bikeindex/omniauth-bike-index) gem

- **Javascript**: [HelloJS](http://adodson.com/hello.js/modules.html#hellojs-already-has-you-connected) Bike Index Module


<a class="ref" id="ref_oauth_flows">

###OAuth Flows

There are two supported ways of authenticating with Bike Index through OAuth2:

1. **Authorization flow**, also called Explicit grant flow. If you create a token on this page, this what the token is created with.

2. **Client-side flow**, also called Implicit grant flow or Bearer flow.


The Authorization flow enables long lived access through refresh tokens (instead of logging out the user every hour), is more secure, and is generally what you should be using. Learn more about [Authorization flow in OAuth2](http://labs.hybris.com/2012/06/01/oauth2-authorization-code-flow).

The Client-side flow is good for client-side javascript apps. Here's an article on [Client-side flow in OAuth2](http://labs.hybris.com/2012/06/05/oauth2-the-implicit-flow-aka-as-the-client-side-flow/).

*There will be rate limiting on the future for non-authenticated requests - so if you have an access token, consider using it for everything.*

<a class="ref" id="ref_applications_authorized">

###Applications you've authorized

Review the applications you've authorized at [/oauth/authorized_applications](/oauth/authorized_applications).

<a class="ref" id="ref_sending_in_requests">

###Sending your access tokens in requests

By default we authenticate you with HTTP Basic authentication scheme. If the basic auth is not found in the authorization header, then it falls back to post parameters. We recommend putting the authentication information in the header.

All the authenticated requests in this documentation put the access token in the parameters for clarity


<a class="ref" id="ref_refresh_tokens">

###Refresh tokens

Since tokens provide access to someone's account, one of the ways OAuth2 keeps things secure is by having tokens expire - so if someone compromises an access token, they don't have unlimited access to an account. The Bike Index expires tokens after 1 hour.

When your access token expires, you can get a new one by making a POST request with your app id and the refresh token:

    POST <%= ENV['BASE_URL'] %>/oauth/token?grant_type=refresh_token&client_id={app_id}&refresh_token={refresh_token}


<!-- 
    $.ajax({
      type: "POST",
      url: "<%= ENV['BASE_URL'] %>",
      data: {
        "code": "@access_code",
        "client_secret": "@applicationsecret}",
        "client_id": "@applicationuid}",
        "grant_type": "authorization_code",
        "redirect_uri": authorize_documentation_index_url
      },
      success: function(data, textStatus, jqXHR) {
        $('#access_grant_response').text(JSON.stringify(data,undefined,2));
      },
      error: function(data, textStatus, jqXHR) {
        $('#access_grant_response').text(JSON.stringify(data, void 0, 2));
      }
    });
 -->