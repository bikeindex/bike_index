# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = 'https://bikeindex.org'
SitemapGenerator::Sitemap.sitemaps_host = 'https://bikeindex.org'
SitemapGenerator::Sitemap.public_path = "#{Rails.root}/tmp/uploads"
SitemapGenerator::Sitemap.sitemaps_path = 'sitemaps/'
SitemapGenerator::Sitemap.adapter = SitemapGenerator::WaveAdapter.new

SitemapGenerator::Sitemap.create do
  group(filename: :about) do
    paths = ['about']
    paths.each { |i| add "/#{i}", priority: 0.9 }
  end

  group(filename: :news) do
    add '/blogs', priority: 0.9, changefreq: 'daily'
    Blog.published.each do |b|
      add("/news/#{b.title_slug}",
          priority: 0.9,
          news: {
            publication_name: 'Bike Index Blog',
            publication_language: 'en',
            title: b.title,
            publication_date: b.published_at.strftime('%Y-%m-%dT%H:%M:%S+00:00')
          })
    end
  end
  group(filename: :partners) do
    paths = ['where', 'organizations/new']
    paths.each { |i| add "/#{i}", priority: 0.9 }
  end

  group(filename: :documentation) do
    add '/documentation/api_v2'
  end

  group(filename: :bikes) do
    Bike.all.each { |b| add bike_path(b), changefreq: 'daily', priority: 0.9 }
  end

  group(filename: :images) do
    PublicImage.bikes.each do |i|
      bike = Bike.where(id: i.imageable_id).first
      if bike.present?
        add(bike_path(i.imageable), images: [{ loc: i.image_url, title: i.name }])
      end
    end
  end
  group(filename: :users) do
    User.where(show_bikes: true).each { |u| add "/users/#{u.username}", priority: 0.4 }
  end

  group(filename: :contact) do
    paths = ['/help']
    paths.each { |i| add "/#{i}", priority: 0.8 }
  end

  group(filename: :resources) do
    paths = %w(resources serials stolen image_resources protect_your_bike how_not_to_buy_stolen)
    paths.each { |i| add "/#{i}" }
  end
end
