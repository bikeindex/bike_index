<a class="ref" id="ref_title">

#Bike Index API V3
  

The Bike Index is open source. You can [view the source code on GitHub](https://github.com/bikeindex/bike_index)&mdash;the API is in [app/controllers/api/v3](https://github.com/bikeindex/bike_index/tree/master/app/controllers/api/v3) and the tests for it are in [spec/api/v3](https://github.com/bikeindex/bike_index/tree/master/spec/api/v3).

If you encounter any errors here (or anywhere on the Bike Index), please [submit an issue on GitHub](https://github.com/bikeindex/bike_index/issues/new).

If you have questions contact [admin@bikeindex.org](mailto:admin@bikeindex.org").

This documentation displays the port number in the demo requests - e.g. [bikeindex.org:**443**/api/v3/bikes_search](https://bikeindex.org/api/v3/bikes_search). While this works, it's unnecessary. You can remove the `:443` - e.g. bikeindex.org/api/v3/bikes_search.

*This documentation isn't tested or supported in IE, we recommend you use a different browser*


<a class="ref" id="ref_introduction">
  
##Introduction

The Bike Index API is organized around REST. Our API is designed to have predictable, resource-oriented URLs and to use HTTP response codes to indicate API errors. JSON will be returned in all responses from the API, including errors.

<a class="ref" id="ref_cors">
  
###CORS

Every endpoint on the Bike Index API supports Cross-Origin Resource Sharing (CORS).

The CORS spec allows web applications to make cross domain AJAX calls without using workarounds such as JSONP. For more information about CORS, read [this article](http://www.nczonline.net/blog/2010/05/25/cross-domain-ajax-with-cross-origin-resource-sharing/), or [the spec](http://www.w3.org/TR/access-control/#simple-cross-origin-request-and-actual-r").

<a class="ref" id="ref_errors">

###Errors

The Bike Index uses HTTP response codes to indicate success or failure of an API request. In general, codes in the 2xx range indicate success, codes in the 4xx range indicate an error that resulted from the provided information (e.g. a required parameter was missing, a charge failed, etc.), and codes in the 5xx range indicate an error with our servers.

Errors respond with a JSON object with a description of the error under the key `error` e.g. `{"error":"Couldn't find Bike with id=XXXXXX"}`.


<a class="ref" id="ref_the_word_bike">
  
###The word "bike"

We use the work "bike" throughout this documentation to mean anything that is registered (be it a tandem, ice-cream cart or standard bicycle). If we are referring specifically to standard bicycles, we make note of that.

You can view <a href="#selections_GET_version_selections_cycle_types_format_get_2" class="scroll-link">all the types of cycles we accept.</a>


<a class="ref" id="ref_bike_urls">
  
###Bike URLs

The HTML pages of the Bike Index follow the same pattern as the API - the url for a bike is https://bikeindex.org/bikes/{bike_id}.


<a class="ref" id="ref_time">
  
###Time

Bike Index API V3 displays everything in <a href="https://en.wikipedia.org/wiki/Unix_time" target="_blank">UTC unix timestamps</a> (integers). All time parameters you send need to use timestamps as well.

<a class="ref" id="ref_authentication">
  
###Authentication

The Bike Index uses OAuth2. <a href="#applications_list" class="scroll-link">Create an application</a> and use an access token for any requests that need authorization.

Endpoints with Red Stars (<span class="accstr">*</span>) require an access token to use.

There is increased rate limiting for non-authenticated requests - including an access token in all requests (even when not required) is a good idea.

<!-- <img alt="example of a protected endpoint" src="updated/documentation/protected_endpoint.png" class="protected-endpoint-img"> -->

