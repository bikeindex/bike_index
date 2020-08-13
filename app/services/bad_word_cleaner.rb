class BadWordCleaner
  BAD_WORDS = %w[ass bastard bitch chink cock cum cunt damn dick fuck nigger shit spic]

  def self.clean(str)
    return nil unless str.present?
    duped_str = str.dup
    BAD_WORDS.each { |w| duped_str.gsub!(/#{w}/i, "*" * w.length) }
    duped_str
  end
end
