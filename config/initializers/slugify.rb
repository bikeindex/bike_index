class Slugifyer
  def self.slugify(string)
    string.gsub(/\s/, '-').gsub(/([^A-Za-z0-9_\-]+)/,'').downcase
  end
  def self.book_slug(string)
    slug = I18n.transliterate(string.downcase)
    slug.gsub(/(bi)?cycles?|bikes?/i,'').gsub('+', 'plus').gsub(/([^A-Za-z0-9])/,' ').strip.gsub(/\s+/, '_')
  end
end