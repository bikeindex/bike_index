# frozen_string_literal: true

# Define a way to check if an update hash matches an object. Particularly useful for request specs
def expect_attrs_to_match_hash(obj, hash, match_time_within: nil)
  unmatched_obj_attrs = {}
  hash.each do |key, value|
    obj_value = obj.send(key)
    # Just in case there are some type issues
    next if obj_value.to_s == value.to_s
    if match_time_within.present? && (obj_value.is_a?(Time) || value.is_a?(Time))
      t_obj_value = obj_value.is_a?(Time) ? obj_value : TimeParser.parse(obj_value)
      t_value = value.is_a?(Time) ? value : TimeParser.parse(value)
      next if t_obj_value.between?(t_value - match_time_within, t_value + match_time_within)
      unmatched_obj_attrs[key] = match_time_within_message(t_obj_value, t_value, match_time_within)
    else
      unmatched_obj_attrs[key] = obj_value
    end
  end
  return true unless unmatched_obj_attrs.present?
  expect(unmatched_obj_attrs).to eq hash.slice(*unmatched_obj_attrs.keys)
end

# Define a hash matchers to display better results and match more loosely (not on type, indifferent access)
def expect_hashes_to_match(hash1, hash2, inside = nil, match_time_within: nil)
  hash1 = hash1.with_indifferent_access if hash1&.is_a?(Hash)
  if hash2.is_a?(Hash)
    hash2 = hash2.with_indifferent_access
    matching_errors = hash1.map { |k, v| match_hash_recursively(k, v, hash2[k], inside, match_time_within) }
      .flatten.compact
    # Make sure we've matched all the keys in the target hash
    unless hash2.keys & hash1.keys == hash2.keys
      matching_errors += [{inside: inside, key: "key mismatch", value: "expected [#{hash2.keys.sort.join(", ")}],\n     got [#{hash1.keys.sort.join(", ")}]"}]
    end
  else
    matching_errors = [{inside: inside, key: "invalid hash", value: "expected a hash, got '#{hash2}'"}]
  end
  # Recurse out if still inside things
  return matching_errors unless inside.blank?
  # Return true if there are no errors
  return nil unless matching_errors.any?
  puts "\nHash mismatches:"

  # This is all displaying error stuff below here
  # group the errors by the insideness
  matching_errors.compact.map { |e| e[:inside] }.uniq.each do |inside_level|
    puts inside_level.present? ? "#{inside_level}:" : "Top level:"
    # Grab the matching insideness errors, turn key and values into a hash to make it better visible
    msg = matching_errors.map { |merror|
      next unless merror[:inside] == inside_level
      [
        merror[:key],
        merror[:message].present? ? merror[:message] : merror[:value]
      ]
    }.compact.to_h
    pp msg
  end
  # give pretty format for failure if possible >
  expect(hash1).to eq hash2
  raise # Backup to ensure this fails if it should (even if the hashes evaluate to equal)
end

def match_hash_recursively(key, value, hash2_value, inside, match_time_within)
  if value.is_a?(Hash)
    return expect_hashes_to_match(value, hash2_value, key, match_time_within: match_time_within)
  elsif value.is_a?(Array) # We handle arrays differently
    # I Fucked this up in PR#62 - I wanted to make it work better, by adding match_array, but it doesn't work anymore at all
    # Someday I will fix this, just not right now
    if (value.count == hash2_value&.count) && value.count < 2 && value.first.is_a?(Hash)
      if value.count > 0
        return expect_hashes_to_match(value[0], hash2_value[0], key, match_time_within: match_time_within)
      end
    elsif hash2_value.is_a?(Array)
      return nil if value == hash2_value # If they are the exact same, let it happen
      # This won't show the keys if it fails, but it's what we want anyway
      return nil unless expect(value).to match_array(hash2_value)
      # return nil # Because the arrays matched
    else
      puts "\nFailure/Error: Tried to compare array to non-array ->"
      # pretty print so that the types are clear
      pp value, hash2_value
      raise "Unable to match array #{key} #{"- inside #{inside}" if inside.present?} - to non-array"
    end
  end
  if match_time_within.present? && (value.is_a?(Time) || hash2_value.is_a?(Time))
    # Converting to time and comparing with #between?
    # I believe this is the best option for the main expected values: Time object or a timestamp
    t_value = value.is_a?(Time) ? value : TimeParser.parse(value)
    t_hash2_value = hash2_value.is_a?(Time) ? hash2_value : TimeParser.parse(hash2_value)
    return nil if t_value.between?(t_hash2_value - match_time_within, t_hash2_value + match_time_within)
    {inside: inside, key: key, value: t_value, message: match_time_within_message(t_value, t_hash2_value, match_time_within)}
  else
    value.to_s == hash2_value.to_s ? nil : {inside: inside, key: key, value: value}
  end
end


def match_time_within_message(value, value2, match_time_within)
  "#{value.to_s} within #{match_time_within} of #{value2.to_s}"
end
