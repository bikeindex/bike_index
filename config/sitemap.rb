# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://bikeindex.org"
# Cloudflare also has a redirect for bikeindex.org/sitemaps/* -> files.bikeindex.org/sitemaps/$1
SitemapGenerator::Sitemap.sitemaps_host = "https://files.bikeindex.org"
SitemapGenerator::Sitemap.public_path = "#{Rails.root}/tmp/uploads"
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"
SitemapGenerator::Sitemap.adapter = SitemapGenerator::WaveAdapter.new

SitemapGenerator::Sitemap.create do
  group(filename: :information) do
    SitemapPages::INFORMATION.each { |i| add("/#{i}", priority: 0.9, changefreq: "weekly") }

    Blog.published.info.find_each do |b|
      next if Blog.top_level_routed.includes?(b.slug)

      add("/info/#{b.title_slug}", priority: 0.9, lastmod: b.updated_at)
    end

    SitemapPages::ADDITIONAL.each { |i| add("/#{i}", priority: 0.8, changefreq: "daily") }

    LandingPages::ORGANIZATIONS.each { |i| add("/o/#{i}", priority: 0.7, changefreq: "weekly") }
  end

  group(filename: :blog) do
    add "/news", priority: 0.9, changefreq: "daily"
    Blog.published.blog.find_each do |b|
      add("/news/#{b.title_slug}", priority: 0.9, lastmod: b.updated_at)
    end
  end

  group(filename: :bikes) do
    Bike.find_each do |b|
      add(bike_path(b),
        changefreq: "daily",
        priority: 0.8,
        lastmod: b.updated_at,
        images: b.public_images.map { |i| {loc: i.image_url, title: i.name} })
    end
  end

  group(filename: :users) do
    User.where(show_bikes: true).find_each { |u| add "/users/#{u.username}", priority: 0.4 }
  end
end
