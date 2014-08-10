if Rails.env.production?
  ROOT_URL = "https://bikeindex.org"
else
  ROOT_URL = "http://bikeindex_public.dev"
  # ROOT_URL = "http://localhost:1308"
end
