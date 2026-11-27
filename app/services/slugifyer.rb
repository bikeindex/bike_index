module Slugifyer
  extend Functionable

  def slugify(string)
    # Apostrophes go before transliterating, which turns curly ones into "?"; other punctuation separates words
    transliterate(CGI.unescapeHTML(string.to_s).delete("'’‘`´").gsub(/\([^)]*\)/, ""))
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

    name = string.gsub(/\sco(\.|mpany)/i, " ").gsub(/\s(frame)?works/i, " ")
    # An empty (bare "Accell") or all-digit slug falls back, since Manufacturer.friendly_find reads digits as an id
    slugify(without_cycle_words(name.gsub(/accell/i, ""))).then { it.match?(/\D/) ? it : slugify(name) }
  end

  # Drops "bike", "e-bike", "bicycles" and the like, which people put in everything
  def without_cycle_words(string) = string.to_s.gsub(/\s(e(lectric)?.?)?((bi)?cycles?|bikes?)/i, " ")

  #
  # private below here
  #

  def transliterate(string)
    I18n.transliterate(string.to_s.downcase).strip
  end

  conceal :transliterate
end
