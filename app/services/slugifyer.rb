class Slugifyer
  def self.slugify(string)
    slug = I18n.transliterate(string.to_s.downcase).strip
    slug.gsub("%20", " ").gsub(/\s/, "-")
      .gsub("-&-", "-amp-") # Replace singular & with amp - since we permit & in names
      .gsub(/([^A-Za-z0-9_\-]+)/, "") # Remove any weird characters
      .downcase
  end

  def self.book_slug(string)
    slug = I18n.transliterate(string.to_s.downcase)
    key_hash = {
      '\s((bi)?cycles?|bikes?)' => " ",
      '\+' => "plus",
      "([^A-Za-z0-9])" => " "
    }
    key_hash.keys.each do |k|
      slug.gsub!(/#{k}/i, key_hash[k])
    end
    slug.strip.gsub(/\s+/, "_") # strip and then turn any length of spaces into underscores
  end

  def self.manufacturer(string)
    return nil unless string
    book_slug(string.gsub(/\sco(\.|mpany)/i, " ")
      .gsub(/\s(frame)?works/i, " ").gsub(/\([^)]*\)/i, ""))
  end
end
