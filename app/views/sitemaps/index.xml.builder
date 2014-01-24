xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  @static_paths.each do |path|
    xml.url do
      xml.loc "#{root_url}#{path}"
      xml.changefreq("weekly")
    end
  end
  @bikes.each do |bike|
    xml.url do
      xml.loc "#{root_url}bikes/#{bike.id}"
      xml.lastmod bike.updated_at.strftime("%F")
      xml.changefreq("weekly")
    end
  end
  @manufacturers.each do |manufacturer|
    xml.url do
      xml.loc "#{root_url}manufacturers/#{manufacturer.slug}"
      xml.lastmod manufacturer.updated_at.strftime("%F")
      xml.changefreq("monthly")
    end
  end
  @users.each do |user|
    xml.url do
      xml.loc "#{root_url}users/#{user.username}"
      xml.lastmod user.updated_at.strftime("%F")
      xml.changefreq("monthly")
    end
  end
  @blogs.each do |blog|
    xml.url do
      xml.loc "#{root_url}blogs/#{blog.title_slug}"
      xml.lastmod blog.published_at.strftime("%F")
      xml.changefreq("monthly")
    end
  end
end