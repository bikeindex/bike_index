class BikeBookIntegration
  require 'net/http'
  
  def make_request(query, method = nil)
    begin
      uri = URI("http://bikebook.io#{method}")
      uri.query = URI.encode_www_form(query)
      res = Net::HTTP.get_response(uri)
    rescue
      return nil
    end
    return nil unless res.is_a?(Net::HTTPSuccess)

    response = JSON.parse(res.body)
    return response if response.kind_of?(Array)
    response.with_indifferent_access     
  end

  def get_model(options = {})
    if options.kind_of?(Bike)
      options = {
        year: options.year,
        manufacturer: options.manufacturer.name,
        frame_model: options.frame_model
      }
    end
    return nil unless options[:year].present? && options[:manufacturer].present? && options[:frame_model].present?
    # We're book sluging everything because, url safe (It's the same method bikebook uses)
    query = { manufacturer: Slugifyer.manufacturer(options[:manufacturer]),
      year: options[:year],
      frame_model: Slugifyer.book_slug(options[:frame_model])
    }

    make_request(query)
  end

  def get_model_list(options = {})
    return nil unless options[:manufacturer].present?
    query = { manufacturer: Slugifyer.manufacturer(options[:manufacturer]) }
    query[:year] = options[:year] if options[:year].present?
    
    make_request(query, "/model_list/")
  end

end