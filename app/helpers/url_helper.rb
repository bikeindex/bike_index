module UrlHelper
  def with_subdomain(subdomain)
  	default_url_options :host => "bikeindex.org"
    subdomain = (subdomain || "")
    subdomain += "." unless subdomain.empty?
    [subdomain, request.domain].join
  end
  
  def url_for(options = nil)
    if options.kind_of?(Hash) && options.has_key?(:subdomain)
      options[:host] = with_subdomain(options.delete(:subdomain))
      options[:port] = request.port_string.gsub(':','') unless request.port_string.empty?
    end
    super
  end
end
