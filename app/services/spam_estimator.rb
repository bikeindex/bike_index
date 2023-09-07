class SpamEstimator
  class << self
    def estimate_bike(bike, stolen_record = nil)
      estimate = 0
      return estimate if bike.blank?
      estimate += 51 if suspicious_string?(bike.frame_model)
      if bike.manufacturer_other
        estimate += 51 if suspicious_string?(bike.manufacturer_other)
      end
      estimate += estimate_stolen_record(stolen_record || bike.current_stolen_record)
      return 0 if estimate < 0
      estimate < 100 ? estimate : 100
    end

    def estimate_stolen_record(stolen_record)
      estimate = 0
      return estimate if stolen_record.blank?
      estimate += 51 if suspicious_string?(stolen_record.theft_description)
      estimate += 51 if suspicious_string?(stolen_record.street)
      estimate
    end

    # eariot are the most frequent letters - this could be incorporated into calculations
    # Currently, doing a weird vowel count thing
    def suspicious_string?(str, str_downlate = nil, str_length = nil)
      return false if str.blank?
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
      elsif str_length < 9
        # Vowel frequencies are more irregular for short strings
        !vowel_percent.between?(0.1, 0.61)
      elsif str_length < 30
        !vowel_percent.between?(0.20, 0.61)
      else
        !vowel_percent.between?(0.20, 0.4)
      end
    end

    def vowel_percentage(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f
      str_downlate ||= downcase_transliterate(str)

      str_downlate.count("aeiouy") / str_length
    end

    def suspicious_capital_count?(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f

      return false if str_length < 6
      capital_ration = str.count("ABCDEFGHIJKLMNOPQRSTUVWXYZ") / str_length
      capital_ration > if str_length < 13
        0.6
      else
        0.41
      end
    end

    def suspicious_space_count?(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f

      return false if str_length < 14
      # Seems like 12 characters is the longest word
      target_space_count = (str_length / 12).floor
      str.count(" -") < target_space_count
    end

    def downcase_transliterate(str)
      I18n.transliterate(str).downcase
    end
  end
end
