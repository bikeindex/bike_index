unless Rails.env.test?
  Geocoder.configure(
    cache: Redis.new,
    lookup: :google,
    use_https: true,
    api_key: ENV.fetch("GOOGLE_GEOCODER"),
    ip_lookup: :maxmind,
    maxmind: { service: :city, api_key: ENV.fetch("MAXMIND_KEY") },
  )
end
