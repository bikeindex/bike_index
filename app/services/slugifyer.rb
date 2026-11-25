module Slugifyer
  extend Functionable

  def slugify(string)
    # Apostrophes go before transliterating, which turns curly ones into "?"; other punctuation separates words
    transliterate(remove_parens(CGI.unescapeHTML(string.to_s).delete("'’‘`´")))
      .gsub("%20", " ")
      .gsub("&", "-and-").gsub("+", "-plus-")
      .gsub(/[^A-Za-z0-9]+/, "-")
      .delete_prefix("-").delete_suffix("-")
  end

  # & slugified to -amp- before it was -and-; nil unless the slug has one
  def amp_as_and(slug) = slug.gsub("-amp-", "-and-").then { it unless it == slug }

  # Drops company suffixes ("Co.", "Works", "Bicycles") and "Accell", which is appended to many of its brands' names
  def broader_company_slugify(string)
    return nil unless string

    name = remove_parens(string).gsub(/\sco(\.|mpany)/i, " ").gsub(/\s(frame)?works/i, " ")
    # An empty (bare "Accell") or all-digit slug falls back, since Manufacturer.friendly_find reads digits as an id
    book_slug(name.gsub(/accell/i, "")).then { it.match?(/\D/) ? it : slugify(name).tr("-", "_") }
  end

  # underscores, also removes some extra stuff
  def book_slug(string)
    slug = transliterate(string)
    key_hash = {
      "%20" => " ",
      '\s(e(lectric)?.?)?((bi)?cycles?|bikes?)' => " ",
      '\+' => "plus",
      "&" => "amp",
      "([^A-Za-z0-9])" => " "
    }
    key_hash.keys.each do |k|
      slug.gsub!(/#{k}/i, key_hash[k])
    end
    slug.strip.gsub(/\s+/, "_") # strip and then turn any length of spaces into underscores
  end

  #
  # private below here
  #

  def remove_parens(string)
    string&.to_s&.gsub(/\([^)]*\)/i, "")
  end

  def transliterate(string)
    I18n.transliterate(string.to_s.downcase).strip
  end

  conceal :remove_parens, :transliterate
end
