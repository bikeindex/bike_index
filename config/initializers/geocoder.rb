unless Rails.env.test?
  Geocoder.configure(
    cache: Redis.new(url: Bikeindex::Application.config.redis_cache_url),
    lookup: :google,
    use_https: true,
    api_key: ENV["GOOGLE_GEOCODER"],
    ip_lookup: :maxmind,
    maxmind: {service: :city, api_key: ENV["MAXMIND_KEY"]}
  )
end
