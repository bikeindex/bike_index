# frozen_string_literal: true

# Tentative review cues for a duplicate registration group. A cue says where to look and why,
# never that a registration is fake, a test or the same physical bicycle as another.
module BikeServices
  module DuplicateReviewCues
    extend Functionable

    Cue = Data.define(:key, :label, :reason, :color) do
      # The review_contact reason names the configured addresses, so JSON gets a generic one
      def as_json(*)
        reason = (key == "review_contact") ? "Initial contact uses a reserved example domain or a reviewer-configured address." : self.reason
        {key:, label:, reason:}.as_json
      end
    end
    NotASerial = Data.define(:kind, :value) do
      def part_number? = kind == :part_number

      def label = "#{part_number? ? "Part number" : "Placeholder"}, not a serial: #{value}"
    end

    REPEATED_CONTACT_MINIMUM = 3
    # Printed on frames and labels, so they get typed into the serial field
    STANDARD_DESIGNATIONS = ["ISO 4210", "ISO 8098", "ISO 6742", "EN 14764", "EN 14765", "EN 14766",
      "EN 14781", "EN 14872", "EN 15194", "EN 15532", "EN 17406", "EN 17128", "EN 14619", "EN 1888",
      "EN 12183", "EN 12184", "DIN 79100", "GB 3565", "GB 17761", "JIS D 9301", "CPSC", "CFR 1512"]
      .to_h { [it, SerialNormalizer.no_space(SerialNormalizer.normalized_and_corrected(it))] }.freeze
    # Typed into the serial field in place of one. A whole-serial match only: a real serial
    # containing one of these words is not affected. Reviewer-curated, extend as found.
    # Other brand names are caught by manufacturer_name_serials
    PLACEHOLDER_SERIALS = ["NO SERIAL NUMBER", "NOSERIAL", "NO NUMBER", "NOT ASSIGNED", "NOT RECORDED",
      "NOT AVAILABLE", "UNAVAILABLE", "UNSURE", "NOT SURE", "PENDING", "PRESALE", "ON ORDER", "PLACEHOLDER",
      "TO BE SPECIFIED", "TO BE ADDED", "TBD SPECIAL ORDER", "TBD BUILDING", "ADD SERIAL", "ADD LATER",
      "WILL ADD", "WILL ADD LATER", "WILL UPDATE", "FILL IN LATER", "ADD AT BUILD", "ADD ON BUILD",
      "ADD SN ON BUILD", "ADD UPON ARRIVAL", "DONT HAVE", "DONT HAVE IT", "I DONT HAVE IT", "CANT FIND",
      "CANNOT FIND", "CANT READ", "UNREADABLE", "ILLEGIBLE", "HIDDEN", "STOLEN",
      "BROMPTON"] # The manufacturer is "Brompton Bicycle", so the name rule misses it
      .to_h { [SerialNormalizer.no_space(SerialNormalizer.normalized_and_corrected(it)), it] }.freeze
    # Component part numbers, which identify a model of part rather than one bicycle
    PART_NUMBER_SERIALS = {
      "170 FC-TY301" => "Shimano Tourney FC-TY301 crankset, 170 mm",
      "SM-BBR60" => "Shimano SM-BBR60 bottom bracket"
    }.to_h { |part, description| [SerialNormalizer.no_space(SerialNormalizer.normalized_and_corrected(part)), description] }.freeze
    # Reserved by RFC 2606 / 6761. Also SQL, matched against an already downcased email
    REVIEW_CONTACT_DOMAIN_PATTERN = '@([^@]+\.)?(example\.(com|net|org)|example|test|invalid|localhost)$'
    REVIEW_CONTACT_DOMAIN_REGEX = Regexp.new(REVIEW_CONTACT_DOMAIN_PATTERN)
    FILTERS = {
      "not_a_serial" => "Placeholder or part number",
      "standard_marking" => "Standards marking in serial",
      "possible_code" => "Possible product, part or placeholder code",
      "test_marker" => "Test markers",
      "review_contact" => "Example-domain contact",
      "single_contact" => "One initial contact",
      "none" => "No tentative cues"
    }.freeze

    def standard_marking(serials)
      normalized = Array(serials).compact.map { SerialNormalizer.no_space(it.to_s.upcase) }
      STANDARD_DESIGNATIONS.find { |_designation, marking| normalized.any? { it.include?(marking) } }&.first
    end

    # Normalized manufacturer names: a brand typed as the serial ("Brompton", "Motobecane") is a placeholder
    def manufacturer_name_serials
      Manufacturer.pluck(:name).filter_map do |name|
        normalized = SerialNormalizer.no_space(SerialNormalizer.normalized_and_corrected(name))
        [normalized, name] if normalized.to_s.length >= 6
      end.to_h
    end

    def cached_manufacturer_name_serials
      # A new manufacturer raises the max id, a rename the max updated_at
      version = Manufacturer.unscope(:order).pick(Arel.sql("max(id)"), Arel.sql("max(updated_at)"))
      Rails.cache.fetch(["duplicate_review_manufacturer_name_serials", *version], expires_in: 1.day) do
        manufacturer_name_serials
      end
    end

    # Whether the whole normalized serial is a known placeholder, part number, manufacturer name
    # or one repeated character. manufacturer_names: is manufacturer_name_serials, or the part of it in use
    def not_a_serial(serial, manufacturer_names: {})
      serial = serial.to_s
      if PLACEHOLDER_SERIALS.key?(serial)
        NotASerial.new(:placeholder, PLACEHOLDER_SERIALS[serial])
      elsif PART_NUMBER_SERIALS.key?(serial)
        NotASerial.new(:part_number, PART_NUMBER_SERIALS[serial])
      elsif manufacturer_names.key?(serial)
        NotASerial.new(:placeholder, "manufacturer name #{manufacturer_names[serial]}")
      elsif serial.match?(/\A(.)\1+\z/)
        NotASerial.new(:placeholder, "one repeated character")
      end
    end

    # A reserved example domain; not part of the test-marker rule
    def review_contact?(email) = email.to_s.strip.downcase.match?(REVIEW_CONTACT_DOMAIN_REGEX)

    def review_contact_sql(column) = "(#{column} ~ '#{REVIEW_CONTACT_DOMAIN_PATTERN}')"

    def cues(serials:, record_count:, contact_count:, test_count:, review_contact_count:, single_contact:, model_match_count: 0, manufacturer_names: {})
      marking = standard_marking(serials)
      not_serial = Array(serials).filter_map { not_a_serial(it, manufacturer_names:) }.first
      code_reasons = [
        ("repeated on #{record_count} live registrations" if record_count >= DuplicateReviewFinder::LARGE_GROUP_MINIMUM),
        ("shared by #{contact_count} different initial contact emails" if contact_count >= REPEATED_CONTACT_MINIMUM),
        ("matches the model text on #{model_match_count} #{"record".pluralize(model_match_count)}" if model_match_count.positive?)
      ].compact
      [
        (if not_serial
           Cue.new("not_a_serial", not_serial.label,
             "The whole serial is #{not_serial.part_number? ? "a component part number" : "a placeholder"} on the reviewer-curated list, so sharing it does not suggest these records are the same bicycle.", :error)
         end),
        (if marking
           Cue.new("standard_marking", "Possible standards marking: #{marking}",
             "The serial contains #{marking}, a safety-standard designation printed on many frames. It may not identify one bicycle.", :warning)
         end),
        (if code_reasons.any?
           Cue.new("possible_code", "Possible product, part or placeholder code",
             "The whole serial is #{code_reasons.to_sentence}. A unique frame serial rarely is.", :warning)
         end),
        (if test_count.positive?
           Cue.new("test_marker", "#{test_count} test-marked",
             "Bike Index administrators organization or the designated test contact, including historical links. A review scope, not permission to delete.", :purple)
         end),
        (if review_contact_count.positive?
           Cue.new("review_contact", "#{review_contact_count} example-domain #{"contact".pluralize(review_contact_count)}",
             "Initial contact uses a reserved example domain (example.com, .test, .invalid and similar). These are not classified as test records.", :orange)
         end),
        (if single_contact
           Cue.new("single_contact", "One initial contact",
             "Every record has the same initial contact email or account. Unverified, and it does not establish the same bicycle.", :notice)
         end)
      ].compact
    end

    def group_cues(group)
      cues(serials: [group["serial"]], record_count: group["record_count"], contact_count: group["email_count"],
        test_count: group["test_count"], review_contact_count: group["review_contact_count"].to_i,
        manufacturer_names: group_manufacturer_names(group),
        single_contact: single_contact?(group))
    end

    # Groups carry the manufacturer name their serial matches, found once when they're prepared
    def group_manufacturer_names(group)
      group["manufacturer_name_serial"] ? {group["serial"] => group["manufacturer_name_serial"]} : {}
    end

    # Every record has one known initial email, or one known account
    def single_contact?(group)
      (group["email_count"] == 1 && group["missing_email_count"].zero?) ||
        (group["account_count"] == 1 && group["missing_account_count"].zero?)
    end

    # The groups matching filter (all of them for an unknown one) and every filter's count,
    # building each group's cues once
    def filter(groups, filter)
      keyed = groups.map { |group| [group, group_cues(group).map(&:key)] }
      counts = FILTERS.keys.to_h { |key| [key, keyed.count { matches_filter?(it.last, key) }] }
      filtered = FILTERS.key?(filter) ? keyed.filter_map { |group, keys| group if matches_filter?(keys, filter) } : groups
      [filtered, counts]
    end

    #
    # private below here
    #

    # One shared contact is context rather than a reason to doubt the serial
    def matches_filter?(keys, filter)
      (filter == "none") ? (keys - ["single_contact"]).none? : keys.include?(filter)
    end

    conceal :matches_filter?
  end
end
