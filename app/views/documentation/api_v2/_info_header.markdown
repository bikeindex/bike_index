
<a id="ref_title">#Bike Index API V2
  

The Bike Index is open source. You can [view the source code on GitHub](https://github.com/bikeindex/bike_index)&mdash;the API is in [app/controllers/v2](https://github.com/bikeindex/bike_index/tree/master/app/controllers/api/v2) and the tests for it are in [spec/api/v2](https://github.com/bikeindex/bike_index/tree/master/spec/api/v2).

If you encounter any errors here (or anywhere on the Bike Index), please [submit an issue on GitHub](https://github.com/bikeindex/bike_index/issues/new).

If you have questions contact [seth@bikeindex.org](mailto:seth@bikeindex.org").

This documentation is temporarily displaying the port number in the demo requests - e.g. [bikeindex.org:**443**/api/v2/bikes_search](https://bikeindex.org/api/v2/bikes_search). While this works, it's unnecessary. You can remove the `:443` - so bikeindex.org/api/v2/bikes_search.

*This documentation isn't tested or supported in IE, we recommend you use a different browser*


<a id="ref_introduction">
  
##Introduction

The Bike Index API is organized around REST. Our API is designed to have predictable, resource-oriented URLs and to use HTTP response codes to indicate API errors. JSON will be returned in all responses from the API, including errors.

<a id="ref_cors">
  
###CORS

Every endpoint on the Bike Index API supports Cross-Origin Resource Sharing (CORS).

The CORS spec allows web applications to make cross domain AJAX calls without using workarounds such as JSONP. For more information about CORS, read [this article](http://www.nczonline.net/blog/2010/05/25/cross-domain-ajax-with-cross-origin-resource-sharing/), or [the spec](http://www.w3.org/TR/access-control/#simple-cross-origin-request-and-actual-r").


<a id="ref_the_word_bike">
  
###The word "bike"

We use the work "bike" throughout this documentation to mean anything that is registered (be it a tandem, ice-cream cart or standard bicycle). If we are referring specifically to standard bicycles, we make note of that.

You can view <a href="#selections_GET_version_selections_cycle_types_format_get_2" class="scroll-link">all the types of cycles we accept.</a>


<a id="ref_bike_urls">
  
###Bike URLs

The HTML pages of the Bike Index follow the same pattern as the API - the url for a bike is https://bikeindex.org/bikes/{bike_id}.


<a id="ref_time">
  
###Time

Bike Index API V2 display everything in <a href="https://en.wikipedia.org/wiki/Unix_time" target="_blank">UTC unix timestamps</a> (integers). All time parameters you send need to use timestamps as well.

<a id="ref_authentication">
  
###Authentication

The Bike Index uses OAuth2. <a href="#applications_list" class="scroll-link">Create an application</a> and use an access token for any requests that need authorization.

Endpoints with Red Stars (<span class="accstr">*</span>) require an access token to use.

<!-- <img alt="example of a protected endpoint" src="/assets/updated/documentation/protected_endpoint.png" class="protected-endpoint-img"> -->

