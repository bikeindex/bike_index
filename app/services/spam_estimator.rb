class SpamEstimator
  class << self
    def estimate_bike(bike, stolen_record = nil)
      estimate = 0
      return estimate if bike.blank?
      estimate += 40 if bike.creation_organization&.spam_registrations
      estimate += 0.5 * string_spaminess(bike.frame_model)
      if bike.manufacturer_other
        estimate += 0.3 * string_spaminess?(bike.manufacturer_other)
      end
      estimate += estimate_stolen_record(stolen_record || bike.current_stolen_record)
      return 0 if estimate < 0
      estimate < 100 ? estimate : 100
    end

    def estimate_stolen_record(stolen_record)
      estimate = 0
      return estimate if stolen_record.blank?
      estimate += 51 if suspicious_string?(stolen_record.theft_description)
      estimate += 21 if suspicious_string?(stolen_record.street)
      estimate
    end

    # eariot are the most frequent letters - this could be incorporated into calculations
    # Currently, doing a weird vowel count thing
    def string_spaminess(str, str_downlate = nil, str_length = nil)
      return 0 if str.blank?
      str_length ||= str.length.to_f
      str_downlate ||= downcase_transliterate(str)
      return 10 if str_length == 1

      vowel_frequency_suspiciousness(str, str_downlate, str_length) +
        space_count_suspiciousness(str, str_downlate, str_length) +
        capital_count_suspiciousness(str, str_downlate, str_length)
    end

    def vowel_frequency_suspiciousness(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f
      vowel_percent = vowel_percentage(str, str_downlate, str_length) * 100

      # In testing vowel percentage, 20-60% is reasonable for short strings
      # longer strings should be below 40%
      centerpoint = 30
      distance_from_center = if vowel_percent > centerpoint
        vowel_percent - centerpoint
      else
        centerpoint - vowel_percent
      end

      susness = if str_length < 5
        # four letter words basically get a pass
        if vowel_percent.between?(5, 80)
          0
        else
          40
        end
      elsif str_length < 30
        if vowel_percent.between?(20, 61)
          0
        else
          # Vowel frequencies are more irregular for short strings
          distance_from_center * (str_length < 10 ? 2 : 5)
        end
      else
        if vowel_percent.between?(20, 4)
          0
        else
          distance_from_center * 10
        end
      end
      # pp "#{str} - susness: #{susness}     distance_from_center: #{distance_from_center.round(2)}   (#{vowel_percent.round(0)})"

      susness > 100 ? 100 : susness
    end



    # ----
    #
    #
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
