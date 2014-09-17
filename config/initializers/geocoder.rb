if Rails.env.production?
  Geocoder.configure(
    :cache      => Redis.new,
    :lookup     => :google, 
    :use_https  => true,
    :api_key    => ENV['GOOGLE_GEOCODER'],
    :ip_lookup  => :maxmind,
    :maxmind    => {:service => :city, api_key: ENV['MAXMIND_KEY'] }
  )
end