xml.instruct!
xml.feed('xml:lang' => 'en-US', xmlns: 'http://www.w3.org/2005/Atom')  do |feed|
  feed.id 'https://bikeindex.org/news.atom'
  feed.link rel: 'alternate', type: 'text/html', href: news_index_url
  feed.link rel: 'self', type: 'application/atom+xml', href: news_index_url('atom')
  feed.title "Bike Index news"
  if @blogs.length > 0
    feed.updated @blogs[0].published_at.to_datetime.rfc3339
  end
  @blogs.each do |blog|
    feed.entry  do |entry|
      entry.published blog.published_at.to_datetime.rfc3339
      entry.id news_url(blog)
      entry.link rel: :alternate, type: 'text/html', href: news_url(blog)
      entry.title blog.title
      entry.updated blog.published_at.to_datetime.rfc3339
      entry.author do |author|
        author.name (blog.user.name)
      end

      entry.content(blog.feed_content, type: 'html')
    end
  end
end