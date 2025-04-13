class Slugifyer
  class << self
    def slugify(string)
      transliterate(remove_parens(string))
        .gsub("%20", " ").gsub(/\s/, "-")
        .gsub("-&-", "-amp-") # Replace singular & with amp - since we permit & in names
        .gsub(/([^A-Za-z0-9_\-]+)/, "") # Remove any weird characters
    end

    def manufacturer(string)
      return nil unless string
      book_slug(
        remove_parens(string).gsub(/\sco(\.|mpany)/i, " ").gsub(/\s(frame)?works/i, " ")
      )
    end

    # underscores, also removes some extra stuff
    def book_slug(string)
      slug = transliterate(string)
      key_hash = {
        "%20" => " ",
        '\s((bi)?cycles?|bikes?)' => " ",
        '\+' => "plus",
        "&" => "amp",
        "([^A-Za-z0-9])" => " "
      }
      key_hash.keys.each do |k|
        slug.gsub!(/#{k}/i, key_hash[k])
      end
      slug.strip.gsub(/\s+/, "_") # strip and then turn any length of spaces into underscores
    end

    private

    def remove_parens(string)
      string&.gsub(/\([^)]*\)/i, "")
    end

    def transliterate(string)
      I18n.transliterate(string.to_s.downcase).strip
    end
  end
end
