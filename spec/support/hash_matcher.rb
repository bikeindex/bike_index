# frozen_string_literal: true

class RspecHashMatcher
  DEFAULT_OPTS = {
    match_time_within: 1.01, # Times within 1 second match
    match_array_order: false,
    match_number_types: false, # i.e. 1 == 1.0
    coerce_values_to_json: false, # JSON doesn't have boolean
    match_timezone_key: false, # timezone is passed in parameters regularly, ignore by default
    match_blanks: false # if false, nil and '' match
  }
  BOOLEANS = [true, false]
  class << self
    def recursive_match_hashes_errors(hash_1, hash_2, inside: [], options: {})
      options = DEFAULT_OPTS.merge(options)
      validate_options!(options)
      match_errors = []
      matched_keys = []
      hash_1_indiff = indifferent_hash(hash_1, hash_2, options[:match_timezone_key])
      hash_2_indiff = indifferent_hash(hash_2, hash_1, options[:match_timezone_key])
      unless hash_1_indiff.is_a?(Hash) && hash_2_indiff.is_a?(Hash)
        return [not_both_hashes(hash_1_indiff, hash_2_indiff, inside: inside)]
      end

      hash_2_indiff.each do |key, value|
        match_value = hash_1_indiff[key]
        if value.is_a?(Hash)
          match_errors += recursive_match_hashes_errors(
            value, match_value, inside: inside << key, options: options
          )
        elsif !values_match?(value, match_value, options: options)
          match_errors << match_error_for(key: key, inside: inside, value: value, match_value: match_value)
        end

        matched_keys << key.to_s
      end

      # Add an error if there are keys missing from hash_1
      unless arrays_match?(matched_keys, hash_1_indiff.keys)
        match_errors << mismatched_keys_error(matched_keys, hash_1_indiff.keys, inside: inside)
      end

      match_errors.flatten.compact
    end

    def match_errors_message(match_errors)
      match_errors.map do |match_error|
        inside_str = if match_error[:inside].present?
          "Inside: {#{match_error[:inside].map { |k| "#{k} => " }.join(" ")}}"
        end

        msg = "Expected #{match_error[:key]}: #{render_error_value(match_error[:value])} to " \
              "#{match_error[:match_with]}: #{render_error_value(match_error[:match_value])}"

        [inside_str, msg].compact.join(", ")
      end.join("\n") + "\n"
    end

    def indifferent_hash(hash_or_obj, hash_to_match, match_timezone_key = false)
      if defined?(hash_or_obj.attributes) && hash_to_match.is_a?(Hash)
        keys = hash_to_match.keys
        keys -= [:timezone, "timezone"] unless match_timezone_key
        keys.index_with { |key| hash_or_obj.send(key) }.with_indifferent_access
      elsif hash_or_obj.is_a?(Hash)
        indiff_hash = hash_or_obj.with_indifferent_access
        match_timezone_key ? indiff_hash : indiff_hash.except(:timezone)
      else
        hash_or_obj
      end
    end

    private

    def validate_options!(options)
      return unless options[:coerce_values_to_json]

      error_messages = []
      if options[:match_number_types]
        error_messages << "`coerce_values_to_json: true` incompatible " \
          "with `match_nuimber_types: true`"
      end

      raise "Invalid options: #{error_messages.join(", ")}" if error_messages.any?
    end

    def not_both_hashes(hash_1, hash_2, inside:)
      match_error_for(key: "hash", inside: inside, value: hash_1, match_value: hash_2,
        match_with: "be a hash")
    end

    def values_match?(value, match_value, options:)
      if value.is_a?(Time) || match_value.is_a?(Time)
        times_match?(value, match_value, match_time_within: options[:match_time_within])
      elsif value.is_a?(Array) && match_value.is_a?(Array)
        arrays_match?(value, match_value, match_array_order: options[:match_array_order])
      elsif value.is_a?(Numeric) || match_value.is_a?(Numeric)
        if options[:match_number_types]
          value == match_value
        else
          value.present? && match_value.present? &&
            BigDecimal(value.to_s) == BigDecimal(match_value.to_s)
        end
      elsif value.is_a?(Symbol) || match_value.is_a?(Symbol)
        value.to_s == match_value.to_s
      elsif options[:coerce_values_to_json]
        value.to_s == match_value.to_s
      elsif BOOLEANS.include?(value) || BOOLEANS.include?(match_value)
        Binxtils::InputNormalizer.boolean(value) == Binxtils::InputNormalizer.boolean(match_value)
      else
        return true if !options[:match_blanks] && value.blank? && match_value.blank?

        value == match_value
      end
    end

    # By default, match within 1 second
    def times_match?(time_1, time_2, match_time_within: nil)
      return false if time_1.blank? || time_2.blank?

      time_1 = Binxtils::TimeParser.parse(time_1) unless time_1.is_a?(Time)
      time_2 = Binxtils::TimeParser.parse(time_2) unless time_2.is_a?(Time)
      match_time_within ||= 1.5
      time_2.utc.between?(time_1.utc - match_time_within, time_1.utc + match_time_within)
    end

    def indifferent_array(array)
      array.map do |item|
        # If the array has hashes, sort them and make them json for better comparison
        item.is_a?(Hash) ? item.as_json.sort.to_json : item.to_s
      end.sort
    end

    # By default, match arrays without worrying about order
    def arrays_match?(array_1, array_2, match_array_order: nil)
      match_array_order ||= false
      return array_1 == array_2 if match_array_order

      indifferent_array(array_1) == indifferent_array(array_2)
    end

    def match_error_for(key:, value:, match_value:, inside:, match_with: "equal")
      {key: key, value: value, match_value: match_value, match_with: match_with}
        .merge(inside.any? ? {inside: inside} : {})
    end

    def mismatched_keys_error(hash_1_keys, hash_2_keys, inside:)
      match_error_for(key: "keys", inside: inside, value: hash_1_keys.sort, match_value: hash_2_keys.sort)
    end

    def render_error_value(obj)
      case obj
      when Numeric then obj
      when String then "'#{obj}'"
      when Time then "'#{obj.round}'"
      else
        obj.inspect
      end
    end
  end
end

# TODO: figure out how to pass options
RSpec::Matchers.define :match_hash_indifferently do |expected|
  match do |actual|
    match_errors = RspecHashMatcher.recursive_match_hashes_errors(expected, actual)

    # If there are any match errors, it didn't match!
    match_errors == []
  end

  failure_message do |actual|
    # Redefine expected  'actual' to be what we're actually comparing against for the diff
    # Symbolize keys because in general, expected has symbolized keys and it improves the diff
    @actual = RspecHashMatcher.indifferent_hash(actual, expected).deep_symbolize_keys

    match_errors = RspecHashMatcher.recursive_match_hashes_errors(expected, actual)
    RspecHashMatcher.match_errors_message(match_errors)
  end

  diffable
end

RSpec::Matchers.define :have_attributes_with_time_within do |expected, time_within: 1|
  match do |actual|
    expected.all? do |key, value|
      actual_value = actual.send(key)
      if value.is_a?(Time)
        actual_value.is_a?(Time) && actual_value.between?(value - time_within, value + time_within)
      else
        values_match?(value, actual_value)
      end
    end
  end

  failure_message do |actual|
    diffs = expected.filter_map do |key, value|
      actual_value = actual.send(key)
      matched = if value.is_a?(Time)
        actual_value.is_a?(Time) && actual_value.between?(value - time_within, value + time_within)
      else
        values_match?(value, actual_value)
      end
      "expected #{key}: #{actual_value.inspect} to match #{value.inspect}" unless matched
    end
    diffs.join("\n")
  end
end
