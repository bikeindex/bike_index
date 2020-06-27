class BadWordCleaner
  BAD_WORDS = %w[fuck shit ass bitch bastard damn cunt cum nigger chink spic]

  def self.clean(str)
    return nil unless str.present?
    BAD_WORDS.each { |w| str.gsub!(/#{w}/i, "*" * w.length) }
    str
  end
end
