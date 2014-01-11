require 'rdiscount'
atom_feed ({:id => request.url}) do |feed|
  feed.title "Bike Index"
  feed.updated(@blogs[0].published_at) if @blogs.length > 0
  @blogs.each do |blog|
    feed.entry blog, published: blog.published_at do |entry|
      entry.title(blog.title)
      entry.content(RDiscount.new(blog.body).to_html, type: 'html')
      entry.author do |author|
        author.name (blog.user.name)
      end
    end
  end
end