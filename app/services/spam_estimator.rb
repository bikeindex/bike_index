class SpamEstimator
  class << self
    def estimate_bike(bike)
      0
    end

    # eariot are the most frequent letters - this could be incorporated into calculations
    # Currently, doing a weird vowel count thing
    def suspicious_string?(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f
      str_downlate ||= downcase_transliterate(str)
      return true if str_length == 1
      return false if str_length < 4
      return true if suspicious_vowel_frequency?(str, str_downlate, str_length)

      return true if suspicious_space_count?(str, str_downlate, str_length)
      suspicious_capital_count?(str, str_downlate, str_length)
    end

    def suspicious_vowel_frequency?(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f
      vowel_percent = vowel_percentage(str, str_downlate, str_length)

      if vowel_percent == 1
        true
      elsif str_length < 5
        # Harder to estimate vowel percentage for short strings
        !vowel_percent.between?(0.15, 0.5)
      else
        !vowel_percent.between?(0.20, 0.55)
      end
    end

    def vowel_percentage(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f
      str_downlate ||= downcase_transliterate(str)

      str_downlate.count("aeiouy") / str_length
    end

    def suspicious_capital_count?(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f

      return false if str_length < 7
      str.count("ABCDEFGHIJKLMNOPQRSTUVWXYZ") / str_length > 0.41
    end

    def suspicious_space_count?(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f

      return false if str_length < 13
      # Seems like 10 characters is the longest word
      target_space_count = (str_length/12).floor
      str.count(" -") < target_space_count
    end

    def downcase_transliterate(str)
      I18n.transliterate(str).downcase
    end
  end
end
