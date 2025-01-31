class SpamEstimator
  MARK_SPAM_PERCENT = 90 # May modify in the future!

  class << self
    def estimate_bike(bike, stolen_record = nil)
      estimate = 0
      return estimate if bike.blank?
      estimate += 35 if bike.creation_organization&.spam_registrations
      estimate += 0.2 * string_spaminess(bike.frame_model)
      estimate += 0.4 * string_spaminess(bike.manufacturer_other)
      estimate += estimate_stolen_record(stolen_record || bike.current_stolen_record)

      within_bounds(estimate)
    end

    # eariot are the most frequent letters - this could be incorporated into calculations
    # Currently, doing a weird vowel count thing
    def string_spaminess(str)
      return 0 if str.blank?
      str_length ||= str.length.to_f
      return 10 if str_length == 1
      str_downlate ||= downcase_transliterate(str)

      total = vowel_frequency_suspiciousness(str, str_length, str_downlate) +
        space_count_suspiciousness(str, str_length, str_downlate) +
        capital_count_suspiciousness(str, str_length, str_downlate) +
        non_letter_count_suspiciousness(str, str_length, str_downlate)

      within_bounds(total)
    end

    private

    def estimate_stolen_record(stolen_record)
      estimate = 0
      return 0 if stolen_record.blank?
      estimate += string_spaminess(stolen_record.theft_description)
      if stolen_record.street.present?
        street_letters = stolen_record.street.gsub(/[^a-z|\s]/, "") # Ignore non letter things from street
        estimate += 0.3 * string_spaminess(street_letters)
      end
      within_bounds(estimate - 20)
    end

    def vowel_frequency_suspiciousness(str, str_length = nil, str_downlate = nil)
      str_length ||= str.length.to_f
      return 0 if str_length < 4 # 3 letters or less get a pass

      vowel_percent = vowel_ratio(str, str_length) * 100
      # In testing vowel percentage, 20-60% is reasonable for short strings
      # longer strings should be below 40%
      susness = if str_length < 6
        [0, 100].include?(vowel_percent) ? 40 : 0
      elsif vowel_percent < 5
        (str_length < 11) ? 80 : 100
      elsif vowel_percent < 20
        offset = (vowel_percent > 12) ? 90 : 120
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
      within_bounds(susness)
    end

    def vowel_ratio(str, str_length = nil, str_downlate = nil)
      str_downlate ||= downcase_transliterate(str)

      only_letters_and_spaces = str_downlate.gsub(/[^a-z|\s]/, "")

      only_letters_and_spaces.count("aeiouy") / only_letters_and_spaces.length.to_f
    end

    def capital_count_suspiciousness(str, str_length = nil, str_downlate = nil)
      str_length ||= str.length.to_f
      return 0 if str_length < 7

      capital_ratio = (str.count("ABCDEFGHIJKLMNOPQRSTUVWXYZ") / str_length) * 100
      susness = if str_length < 16
        capital_ratio - 50
      elsif str_length < 25
        capital_ratio - 40
      else
        capital_ratio - 10
      end
      # People love capitalizing things on the internet :/
      0.3 * within_bounds(susness)
    end

    def non_letter_count_suspiciousness(str, str_length = nil, str_downlate = nil)
      str_length ||= str.length.to_f
      return 0 if str_length < 7

      str_downlate ||= downcase_transliterate(str)
      non_letter_count = (1 - (str_downlate.count("abcdefghijklmnopqrstuvwxyz ") / str_length)) * 100

      susness = if str_length < 16
        non_letter_count - 50
      elsif str_length < 25
        non_letter_count - 40
      else
        non_letter_count - 10
      end
      within_bounds(susness)
    end

    def space_count_suspiciousness(str, str_length = nil, str_downlate = nil)
      str_length ||= str.length.to_f
      return 0 if str_length < 12

      spaces_count = str.count(" -")
      if str_length < 20
        return (spaces_count < 1) ? 10 : 0
      end

      target_space_count = (str_length / 12).floor
      return 0 if spaces_count >= target_space_count

      multiplier = (str_length < 31) ? 40 : 60
      susness = (target_space_count - spaces_count) * multiplier

      within_bounds(susness)
    end

    def within_bounds(num)
      return 0 if num < 0
      (num < 100) ? num : 100
    end

    def downcase_transliterate(str)
      I18n.transliterate(str).downcase
    end
  end
end
