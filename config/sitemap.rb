# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://bikeindex.org"
# Cloudflare also has a redirect for bikeindex.org/sitemaps/* -> files.bikeindex.org/sitemaps/$1
SitemapGenerator::Sitemap.sitemaps_host = "https://files.bikeindex.org"
SitemapGenerator::Sitemap.public_path = "#{Rails.root}/tmp/uploads"
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"
SitemapGenerator::Sitemap.adapter = SitemapGenerator::WaveAdapter.new

SitemapGenerator::Sitemap.create do
  group(filename: :about) do
    %w[about ambassadors_current ambassadors_how_to ascend bike_shop_packages campus_packages
      cities_packages for_bike_shops for_community_groups for_cities for_law_enforcement
      for_schools help recovery_stories].each { |i| add "/#{i}", priority: 0.9, changefreq: "weekly" }
  end

  group(filename: :resources) do
    %w[donate support_bike_index support_the_index support_the_bike_index protect_your_bike
      serials about where vendor_terms resources image_resources privacy terms security
      how_not_to_buy_stolen dev_and_design lightspeed
      why-donate documentation].each { |i| add "/#{i}", priority: 0.9, changefreq: "weekly" }
  end

  group(filename: :organizations) do
    LandingPages::ORGANIZATIONS.each { |i| add "/o/#{i}", priority: 0.9, changefreq: "weekly" }
  end

  group(filename: :info) do
    Blog.published.info.find_each do |b|
      add("/info/#{b.title_slug}", priority: 0.9, lastmod: b.updated_at,
                                   news: {publication_name: "Bike Index Information",
                                          publication_language: "en",
                                          title: b.title,
                                          publication_date: b.published_at})
    end
  end

  group(filename: :news) do
    add "/news", priority: 0.9, changefreq: "daily"
    Blog.published.blog.find_each do |b|
      add("/news/#{b.title_slug}", priority: 0.9, lastmod: b.updated_at,
                                   news: {publication_name: "Bike Index Blog",
                                          publication_language: "en",
                                          title: b.title,
                                          publication_date: b.published_at})
    end
  end

  group(filename: :partners) do
    paths = ["where", "organizations/new"]
    paths.each { |i| add "/#{i}", priority: 0.9 }
  end

  group(filename: :bikes) do
    Bike.find_each do |b|
      add(bike_path(b),
        changefreq: "daily",
        priority: 0.8,
        lastmod: b.updated_at)
    end
  end

  group(filename: :images) do
    Bike.with_public_image.find_each do |bike|
      add(bike_path(i.imageable),
        images: bike.public_images.map { |i| {loc: i.image_url, title: i.name} })
    end
  end

  group(filename: :users) do
    User.where(show_bikes: true).find_each { |u| add "/users/#{u.username}", priority: 0.4 }
  end

  group(filename: :recovery_stories) do
    paths = ["recovery_stories"]
    paths.each { |i| add "/#{i}", priority: 0.8, changefreq: "daily" }
  end
end
