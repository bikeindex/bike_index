module UrlHelper
  def with_subdomain(subdomain)
  	# default_url_options host: "bikeindex.org"
    subdomain = (subdomain || "")
    subdomain += "." unless subdomain.empty?
    [subdomain, request.domain].join
  end
  
  
end
