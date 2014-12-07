atom_feed ({id: request.url, schema_date: 2014}) do |feed|
  feed.title "Bike Index"
  feed.updated(@blogs[0].published_at) if @blogs.length > 0
  @blogs.each do |blog|
    feed.entry blog, published: blog.published_at do |entry|
      entry.title(blog.title)
      entry.content(Kramdown::Document.new(blog.body).to_html, type: 'html')
      entry.author do |author|
        author.name (blog.user.name)
      end
    end
  end
end