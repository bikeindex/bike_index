# frozen_string_literal: true

class RspecHashMatcher
  class << self
    def recursive_match_hashes(hash_1, hash_2, inside: [], match_array_order: nil,
                               match_time_within: nil)
      match_errors = []
      matched_keys = []
      hash_1_indiff = indifferent_hash(hash_1, hash_2)
      hash_2_indiff = indifferent_hash(hash_2, hash_1)
      unless hash_1_indiff.is_a?(Hash) && hash_2_indiff.is_a?(Hash)
        return [not_both_hashes(hash_1_indiff, hash_2_indiff, inside:)]
      end

      hash_2_indiff.each do |key, value|
        match_value = hash_1_indiff[key]
        if value.is_a?(Hash)
          match_errors += recursive_match_hashes(
            value, match_value, inside: inside << key, match_array_order:, match_time_within:
          )
        elsif !values_match?(value, match_value)
          match_errors << match_error_for(key:, inside:, value:, match_value:)
        end

        matched_keys << key.to_s
      end

      # Add an error if there are keys missing from hash_1
      unless arrays_match?(matched_keys, hash_1_indiff.keys)
        match_errors << mismatched_keys_error(matched_keys, hash_1_indiff.keys, inside:)
      end

      match_errors.flatten.compact
    end

    def match_errors_message(match_errors)
      match_errors.map do |match_error|
        inside_str = if match_error[:inside].present?
                       "Inside: {#{match_error[:inside].map { |k| "#{k} => " }.join(' ')}}"
                     end

        msg = "Expected #{match_error[:key]}: #{render_error_value(match_error[:value])} to " \
              "#{match_error[:match_with]}: #{render_error_value(match_error[:match_value])}"

        [inside_str, msg].compact.join(", ")
      end.join("\n") + "\n"
    end

    def indifferent_hash(hash_or_obj, hash_to_match)
      if defined?(hash_or_obj.attributes) && hash_to_match.is_a?(Hash)
        hash_to_match.keys.index_with { |key| hash_or_obj.send(key) }.with_indifferent_access
      elsif hash_or_obj.is_a?(Hash)
        hash_or_obj.with_indifferent_access
      else
        hash_or_obj
      end
    end

    private

    def not_both_hashes(hash_1, hash_2, inside:)
      match_error_for(key: "hash", inside:, value: hash_1, match_value: hash_2,
                      match_with: "be a hash")
    end

    def values_match?(value, match_value, match_array_order: nil, match_time_within: nil)
      if value.is_a?(Time) && match_value.is_a?(Time)
        times_match?(value, match_value, match_time_within:)
      elsif value.is_a?(Array) && match_value.is_a?(Array)
        arrays_match?(value, match_value, match_array_order:)
      else
        value.to_s == match_value.to_s
      end
    end

    # By default, match within 1 second
    def times_match?(time_1, time_2, match_time_within: nil)
      match_time_within ||= 1.5
      time_2.between?(time_1 - match_time_within, time_1 + match_time_within)
    end

    # By default, match arrays without worrying about order
    def arrays_match?(array_1, array_2, match_array_order: nil)
      match_array_order ||= false
      return array_1 == array_2 if match_array_order

      array_1.map(&:to_s).sort == array_2.map(&:to_s).sort
    end

    def match_error_for(key:, value:, match_value:, inside:, match_with: "equal")
      { key:, value:, match_value:, match_with: }.merge(inside.any? ? { inside: } : {})
    end

    def mismatched_keys_error(hash_1_keys, hash_2_keys, inside:)
      match_error_for(key: 'keys', inside:, value: hash_1_keys.sort, match_value: hash_2_keys.sort)
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

# TODO: figure out how to pass match_array_order and match_time_within

RSpec::Matchers.define :match_hash_flexibly do |expected|
  match do |actual|
    match_errors = RspecHashMatcher.recursive_match_hashes(expected, actual)

    # If there are any match errors, it didn't match!
    match_errors == []
  end

  failure_message do |actual|
    # Redefine expected  'actual' to be what we're actually comparing against for the diff
    # Symbolize keys because in general, expected has symbolized keys and it improves the diff
    @actual = RspecHashMatcher.indifferent_hash(actual, expected).deep_symbolize_keys
    match_errors = RspecHashMatcher.recursive_match_hashes(expected, actual)
    RspecHashMatcher.match_errors_message(match_errors)
  end

  diffable
end
