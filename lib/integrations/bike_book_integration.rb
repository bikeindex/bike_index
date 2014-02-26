class BikeBookIntegration
  require 'net/http'
  
  def make_request(query = nil)
    uri = URI('http://bikebook.io')
    uri.query = URI.encode_www_form(query)
    res = Net::HTTP.get_response(uri)
    
    if res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body).with_indifferent_access 
    else
      nil
    end
  end

  def get_model(bike)
    return nil unless bike.year.present? && bike.manufacturer.present? && bike.frame_model.present?
    # We're book sluging everything because, url (It's the same method bikebook uses)
    query = { manufacturer: Slugifyer.book_slug(bike.manufacturer.name),
      year: bike.year,
      frame_model: Slugifyer.book_slug(bike.frame_model)
    }

    make_request(query)
  end

end