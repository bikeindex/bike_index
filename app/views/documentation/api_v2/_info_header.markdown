#Bike Index API V2 <a id="ref_title">

The Bike Index is open source. You can [view the source code on GitHub](https://github.com/bikeindex/bike_index)&mdash;the API is in [app/controllers/v2](https://github.com/bikeindex/bike_index/tree/master/app/controllers/api/v2) and the tests for it are in [spec/api/v2](https://github.com/bikeindex/bike_index/tree/master/spec/api/v2).

If you encounter any errors here (or anywhere on the Bike Index), please [submit an issue on GitHub](https://github.com/bikeindex/bike_index/issues/new).

If you have questions contact [seth@bikeindex.org](mailto:seth@bikeindex.org").

*This documentation isn't tested or supported in IE.*


##Introduction <a id="ref_introduction">

The Bike Index API is organized around REST. Our API is designed to have predictable, resource-oriented URLs and to use HTTP response codes to indicate API errors. JSON will be returned in all responses from the API, including errors.

###CORS <a id="ref_cors">

Every endpoint on the Bike Index API supports Cross-Origin Resource Sharing (CORS).

The CORS spec allows web applications to make cross domain AJAX calls without using workarounds such as JSONP. For more information about CORS, read [this article](http://www.nczonline.net/blog/2010/05/25/cross-domain-ajax-with-cross-origin-resource-sharing/), or [the spec](http://www.w3.org/TR/access-control/#simple-cross-origin-request-and-actual-r").


###The word "bike" <a id="ref_the_word_bike">

We use the work "bike" throughout this documentation to mean anything that is registered (be it a tandem, ice-cream cart or standard bicycle). If we are referring specifically to standard bicycles, we make note of that.

You can view <a href="#selections_GET_version_selections_cycle_types_format_get_2" class="scroll-link">all the types of cycles we accept.</a>


###Bike URLs <a id="ref_bike_urls">

The HTML pages of the Bike Index follow the same pattern as the API - the url for a bike is https://bikeindex.org/bikes/{bike_id}.


###Time <a id="ref_time">

Bike Index API V2 display everything in <a href="https://en.wikipedia.org/wiki/Unix_time" target="_blank">UTC unix timestamps</a> (integers). All time parameters you send need to use timestamps as well.