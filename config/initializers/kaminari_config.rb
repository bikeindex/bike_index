Kaminari.configure do |config|
  config.default_per_page = 25
  config.max_per_page = 100
  config.max_pages = 5_000 # Stop paging through everything
end
