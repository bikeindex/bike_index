#Bike Index API V2#

The Bike Index is open source. You can [view the source code on GitHub](https://github.com/bikeindex/bike_index)&mdash;the API is in [app/controllers/v2](https://github.com/bikeindex/bike_index/tree/master/app/controllers/api/v2) and the tests for it are in [spec/api/v2](https://github.com/bikeindex/bike_index/tree/master/spec/api/v2).

If you encounter any errors here (or anywhere on the Bike Index), please [submit an issue on GitHub](https://github.com/bikeindex/bike_index/issues/new).

If you have questions contact [seth@bikeindex.org](mailto:seth@bikeindex.org").


##Introduction##

The Bike Index API is organized around REST. Our API is designed to have predictable, resource-oriented URLs and to use HTTP response codes to indicate API errors. JSON will be returned in all responses from the API, including errors.

This documentation is interactive to help you figure out how to use the API. It isn't tested or supported in IE.


###Authentication###

The Bike Index uses OAuth2. <a href="#applications_list" class="scroll-link">Create an application</a> and use an access token for any requests that need authorization.

Endpoints with Red Stars (<span class="accstr">*</span>) require an access token to use:

<img alt="example of a protected endpoint" src="/assets/updated/documentation/protected_endpoint.png" class="protected-endpoint-img">

Libraries and external tools for the Bike Index <a href="#authentication" class="scroll-link">are available at the bottom of the page</a>, along with some more information about our implementation of OAuth.

*There may be rate limiting on the future for non-authenticated requests - so if you have an access token, consider using it for everything.*


###Bike###

We use the work "bike" throughout this documentation to mean anything that is registered (be it a tandem, ice-cream cart or standard bicycle). If we are referring specifically to standard bicycles, we make note of that.

You can view <a href="#selections_GET_version_selections_cycle_types_format_get_2" class="scroll-link">all the types of cycles we accept.</a>


###Bike URLs###

For the HTML pages of the Bike Index follow the same pattern as the API - the url for a bike is https://bikeindex.org/bikes/{bike_id}.


###Time###

Bike Index API V2 display everything in <a href="https://en.wikipedia.org/wiki/Unix_time" target="_blank">UTC unix timestamps</a> (integers). All time parameters you send need to use timestamps as well.