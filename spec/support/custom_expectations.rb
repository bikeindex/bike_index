# frozen_string_literal: true

# Define a hash matchers to display better results and match more loosely (not on type, indifferent access)
def expect_hashes_to_match(hash1, hash2, inside = nil)
  hash1 = hash1.with_indifferent_access if hash1&.is_a?(Hash)
  if hash2.is_a?(Hash)
    hash2 = hash2.with_indifferent_access
    matching_errors = hash1.map { |k, v| match_hash_recursively(k, v, hash2[k], inside) }
                           .flatten.compact
    # Make sure we've matched all the keys in the target hash
    unless hash2.keys & hash1.keys == hash2.keys
      matching_errors += [{ inside: inside, key: "key mismatch", value: "expected [#{hash2.keys.sort.join(", ")}],\n     got [#{hash1.keys.sort.join(", ")}]" }]
    end
  else
    matching_errors = [{ inside: inside, key: "invalid hash", value: "expected a hash, got '#{hash2}'" }]
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
    msg = matching_errors.map do |merror|
      next unless merror[:inside] == inside_level
      [merror[:key], merror[:value]]
    end.compact.to_h
    pp msg
  end
  # give pretty format for failure if possible >
  expect(hash1).to eq hash2
  raise # Backup to ensure this fails if it should (even if the hashes evaluate to equal)
end

def match_hash_recursively(key, value, hash2_value, inside)
  if value.is_a?(Hash)
    return expect_hashes_to_match(value, hash2_value, key)
  elsif value.is_a?(Array) # We handle arrays differently
    # I Fucked this up in PR#62 - I wanted to make it work better, by adding match_array, but it doesn't work anymore at all
    # Someday I will fix this, just not right now
    if (value.count == hash2_value&.count) && value.count < 2
      return expect_hashes_to_match(value[0], hash2_value[0], key) if value.count > 0
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
  value.to_s == hash2_value.to_s ? nil : { inside: inside, key: key, value: value }
end
