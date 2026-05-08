module SpamEstimator
  extend Functionable

  MARK_SPAM_PERCENT = 90 # May modify in the future!

  MALICIOUS_REGEX = /
    <\s*(?:script|iframe|object|embed)[\s>\/] |
    javascript\s*: |
    <[^>]*\son\w+\s*= |
    \bunion\s+select\b |
    \b(?:drop|truncate)\s+table\b |
    \b(?:delete\s+from|insert\s+into)\b |
    ['"]\s*or\s+['"]?\d+['"]?\s*=\s*['"]?\d+ |
    \bpg_sleep\s*\( |
    ;\s*(?:drop|delete|truncate|exec)\b
  /xi

  def estimate_bike(bike, stolen_record = nil, skip_malicious: false)
    estimate = 0
    return estimate if bike.blank?
    return 100 if !skip_malicious && looks_malicious?(bike.cached_data)

    estimate += 35 if bike.creation_organization&.spam_registrations
    estimate += 0.2 * string_spaminess(bike.frame_model, skip_malicious:)
    estimate += 0.4 * string_spaminess(bike.manufacturer_other, skip_malicious:)
    estimate += domain_estimate(bike.owner_email)
    estimate += estimate_stolen_record(stolen_record || bike.current_stolen_record)

    within_bounds(estimate)
  end

  # eariot are the most frequent letters - this could be incorporated into calculations
  # Currently, doing a weird vowel count thing
  def string_spaminess(str, skip_malicious: false)
    return 0 if str.blank?
    return 100 if !skip_malicious && looks_malicious?(str)

    str_length ||= str.length.to_f
    return 10 if str_length == 1

    str_downlate ||= downcase_transliterate(str)

    total = vowel_frequency_suspiciousness(str, str_length, str_downlate) +
      space_count_suspiciousness(str, str_length, str_downlate) +
      capital_count_suspiciousness(str, str_length, str_downlate) +
      non_letter_count_suspiciousness(str, str_length, str_downlate)

    within_bounds(total)
  end

  #
  # private below here
  #

  def looks_malicious?(str)
    return false if str.blank?

    str.match?(MALICIOUS_REGEX)
  end

  def domain_estimate(email)
    return 0 unless EmailDomain::VERIFICATION_ENABLED

    email_domain = EmailDomain.find_or_create_for(email)

    return 0 if email_domain.blank? || email_domain.permitted?

    # If it's banned, it's spam - otherwise increase spam likelihood (pending_ban)
    email_domain.banned? ? 100 : 40
  end

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
    num.clamp(0, 100)
  end

  def downcase_transliterate(str)
    I18n.transliterate(str).downcase
  end

  conceal :looks_malicious?, :domain_estimate, :estimate_stolen_record,
    :vowel_frequency_suspiciousness, :vowel_ratio,
    :capital_count_suspiciousness, :non_letter_count_suspiciousness,
    :space_count_suspiciousness, :within_bounds, :downcase_transliterate
end
