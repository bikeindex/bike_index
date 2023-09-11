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

      total = vowel_frequency_suspiciousness(str, str_downlate, str_length) +
        space_count_suspiciousness(str, str_downlate, str_length) +
        capital_count_suspiciousness(str, str_downlate, str_length)

      total / 3
    end

    def vowel_frequency_suspiciousness(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f
      return 0 if str_length < 4 # 3 letters or less get a pass
      vowel_percent = vowel_ratio(str, str_downlate, str_length) * 100

      # In testing vowel percentage, 20-60% is reasonable for short strings
      # longer strings should be below 40%
      susness = if str_length < 6
        [0, 100].include?(vowel_percent) ? 40 : 0
      elsif vowel_percent < 5
        str_length < 11 ? 80 : 100
      elsif vowel_percent < 20
        offset = vowel_percent > 12 ? 90 : 120
        if str_length < 9
          offset -= 50
        elsif str_length < 14
          offset -= 20
        elsif str_length < 30
          offset -= 10
        end
        offset - vowel_percent
      elsif vowel_percent > 69
        if str_length < 15
          vowel_percent
        elsif str_length < 30
          vowel_percent + 15
        else
          100
        end
      elsif vowel_percent > 40
        vowel_percent - 40
      else
        0
      end

      # pp "#{str} - susness: #{susness}    (#{vowel_percent.round(0)})"

      susness > 100 ? 100 : susness
    end


    def vowel_ratio(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f
      str_downlate ||= downcase_transliterate(str)

      str_downlate.count("aeiouy") / str_length
    end

    def capital_count_suspiciousness(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f

      return false if str_length < 6
      capital_ration = str.count("ABCDEFGHIJKLMNOPQRSTUVWXYZ") / str_length
      capital_ration > if str_length < 13
        0.6
      else
        0.41
      end
    end

    def space_count_suspiciousness(str, str_downlate = nil, str_length = nil)
      str_length ||= str.length.to_f
      return 0 if str_length < 12

      spaces_count = str.count(" -")
      if str_length < 20
        return spaces_count < 1 ? 10 : 0
      end

      target_space_count = (str_length / 12).floor
      return 0 if spaces_count >= target_space_count

      multiplier = str_length < 31 ? 40 : 60
      susness = (target_space_count - spaces_count) * multiplier
      susness > 100 ? 100 : susness
    end

    def downcase_transliterate(str)
      I18n.transliterate(str).downcase
    end
  end
end
