class Urlifyer
  # This is sketchy, it can fail and not tell anyone anything
  # but if we don't put in http:// when people enter input, it won't link correctly.
  # TODO: Improve this, add errors or something
  
  def self.urlify(string)
    if string && string.length > 1
      return string if string.match(/http.?:\/\//i).present?
      "http://#{string}" 
    end
  end

  def self.is_url(string)
    true if self.uri?('http://' + string)
  end

  def self.uri?(string)
    uri = URI.parse(string)
    %w( http https ).include?(uri.scheme)
    rescue URI::BadURIError
      false
    rescue URI::InvalidURIError
      false
  end

end
