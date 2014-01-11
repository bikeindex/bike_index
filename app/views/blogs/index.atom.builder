require 'rdiscount'
atom_feed do |feed|
  feed.title "Bike Index Blog Articles"
  feed.updated(@blogs[0].published_at) if @blogs.length > 0
  @blogs.each do |article|
    feed.entry article, published: article.published_at do |entry|
      entry.title(article.title)
      entry.content(RDiscount.new(article.body).to_html, type: 'html')
      entry.author do |author|
        author.name (article.user.name)
      end
    end
  end
end