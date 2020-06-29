class BadWordCleaner
  BAD_WORDS = %w[ass bastard bitch chink cock cum cunt damn dick fuck nigger shit spic]

  def self.clean(str)
    return nil unless str.present?
    BAD_WORDS.each { |w| str.gsub!(/#{w}/i, "*" * w.length) }
    str
  end
end
