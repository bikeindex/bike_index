require "did_you_mean/levenshtein"

class DuplicateBikeReview
  ContactGroup = Data.define(:number, :email, :bikes) do
    # Never the email itself
    def as_json(*)
      {number:, email_present: !email.nil?, bike_ids: bikes.map(&:id),
       review_contact: BikeServices::DuplicateReviewCues.review_contact?(email)}.as_json
    end
  end
  Check = Data.define(:status, :label)
  # Separate review, never invitation candidates
  SEPARATE_REVIEW_CUES = %w[not_a_serial standard_marking possible_code test_marker review_contact].freeze

  FIELDS = {
    "Manufacturer" => ->(bike) { [bike.manufacturer&.name, bike.manufacturer_other].compact_blank.join(" ") },
    "Model" => ->(bike) { bike.frame_model },
    "Year" => ->(bike) { bike.year },
    "Primary color" => ->(bike) { bike.primary_frame_color&.name },
    "Vehicle type" => ->(bike) { bike.cycle_type&.humanize },
    "Stored serial" => ->(bike) { bike.serial_number },
    "Whole normalized serial" => ->(bike) { bike.serial_normalized_no_space },
    "Status" => ->(bike) { bike.status&.humanize }
  }.freeze

  attr_reader :bikes, :reference_bike, :manufacturer_names

  # The first ownership: no previous one, then the earliest
  def self.initial_ownership(bike)
    bike&.ownerships&.min_by { |ownership| [ownership.previous_ownership_id.nil? ? 0 : 1, ownership.created_at || Time.at(0), ownership.id || 0] }
  end

  # manufacturer_names: is DuplicateReviewCues.manufacturer_name_serials, so a brand typed as the serial is caught
  def initialize(bikes:, reference_bike: nil, manufacturer_names: {})
    @bikes = bikes
    @reference_bike = reference_bike || bikes.first
    @manufacturer_names = manufacturer_names
  end

  def serial_match(bike)
    serial = bike.serial_normalized_no_space.to_s
    reference_serial = reference_bike&.serial_normalized_no_space.to_s
    return "Whole serial unavailable" if serial.empty? || reference_serial.empty?

    (serial == reference_serial) ? "Whole normalized serial matches" : "Whole normalized serial differs"
  end

  def manufacturer_match(bike)
    return "Manufacturer unavailable" if bike.manufacturer_id.nil? || reference_bike&.manufacturer_id.nil?
    return "Manufacturer differs" if bike.manufacturer_id != reference_bike.manufacturer_id
    return "Custom manufacturer details differ" if bike.manufacturer_other.to_s.strip.downcase != reference_bike.manufacturer_other.to_s.strip.downcase

    "Manufacturer matches"
  end

  def initial_ownership(bike)
    @initial_ownerships ||= {}
    @initial_ownerships.fetch(bike) { @initial_ownerships[bike] = self.class.initial_ownership(bike) }
  end

  def claim_status(ownership)
    return "Unavailable" if ownership.nil?

    (ownership.claimed || ownership.claimed_at) ? "Claimed" : "Unclaimed"
  end

  def contact_email(ownership)
    ownership.owner_email if normalized_email(ownership)
  end

  def account_match(bike, initial: false)
    ownership = initial ? initial_ownership(bike) : bike.current_ownership
    reference_ownership = initial ? initial_ownership(reference_bike) : reference_bike&.current_ownership
    return "Account unavailable" if ownership&.user_id.nil? || reference_ownership&.user_id.nil?

    (ownership.user_id == reference_ownership.user_id) ? "Same account" : "Different accounts"
  end

  def email_match(bike, initial: false)
    ownership = initial ? initial_ownership(bike) : bike.current_ownership
    reference_ownership = initial ? initial_ownership(reference_bike) : reference_bike&.current_ownership
    email = normalized_email(ownership)
    reference_email = normalized_email(reference_ownership)
    return "Email unavailable" if email.nil? || reference_email.nil?

    (email == reference_email) ? "Same email" : "Different emails"
  end

  def email_evidence(bike, initial: false)
    ownership = initial ? initial_ownership(bike) : bike.current_ownership
    reference_ownership = initial ? initial_ownership(reference_bike) : reference_bike&.current_ownership
    email = normalized_email(ownership)
    reference_email = normalized_email(reference_ownership)
    return "Email unavailable" if email.nil? || reference_email.nil?
    return "Exact normalized email" if email == reference_email
    return "Same local part, different domains (identity unverified)" if email.split("@").first == reference_email.split("@").first
    return "Different emails (identity unverified)" if email.length > 255 || reference_email.length > 255

    distance = DidYouMean::Levenshtein.distance(email, reference_email)
    (distance <= 2) ? "#{distance} email character edits (identity unverified)" : "Different emails (identity unverified)"
  end

  def field_value(bike, field)
    FIELDS.fetch(field).call(bike).to_s.strip.presence
  end

  # [value, record count] pairs, most common first; a nil value is a blank field
  def distribution(&block) = bikes.map(&block).tally.sort_by { |value, count| [-count, value.to_s] }

  def field_distribution(field)
    @field_distribution ||= {}
    @field_distribution[field] ||= distribution { field_value(it, field) }
  end

  def source(bike)
    ownership = initial_ownership(bike)
    return "#{ownership.pos_kind.delete_suffix("_pos").humanize} POS" if %w[lightspeed_pos ascend_pos].include?(ownership&.pos_kind)

    ownership&.origin&.humanize
  end

  def organization(bike) = initial_ownership(bike)&.organization || bike.creation_organization

  def transferred?(bike) = bike.ownerships.any?(&:previous_ownership_id)

  def shared_fields = @shared_fields ||= FIELDS.keys.select { field_distribution(it).size == 1 }

  def differing_fields = @differing_fields ||= FIELDS.keys - shared_fields

  # The fields where this record departs from the group's most common value
  def differences(bike)
    differing_fields.reject { field_value(bike, it) == field_distribution(it).first.first }
  end

  # Grouped by the normalized initial email. Records without one are a single group,
  # since an absent email can't establish that two of them share a contact
  def contact_groups
    @contact_groups ||= bikes.group_by { normalized_email(initial_ownership(it)) }
      .sort_by { |email, records| [email.nil? ? 1 : 0, -records.size, records.map(&:created_at).compact.min || Time.at(0)] }
      .each_with_index.map { |(email, records), index| ContactGroup.new(number: index + 1, email:, bikes: records) }
  end

  def contact_group(bike)
    @contact_group_by_bike ||= contact_groups.flat_map { |group| group.bikes.map { [it, group] } }.to_h
    @contact_group_by_bike[bike]
  end

  def not_a_serial
    bikes.map(&:serial_normalized_no_space).uniq
      .filter_map { BikeServices::DuplicateReviewCues.not_a_serial(it, manufacturer_names:) }.first
  end

  def initial_emails = @initial_emails ||= bikes.filter_map { normalized_email(initial_ownership(it)) }

  def review_contact_count
    @review_contact_count ||= bikes.count { BikeServices::DuplicateReviewCues.review_contact?(normalized_email(initial_ownership(it))) }
  end

  def model_match_count
    bikes.count do |bike|
      serial = bike.serial_normalized_no_space.to_s
      model = SerialNormalizer.no_space(SerialNormalizer.normalized_and_corrected(bike.frame_model)).to_s
      serial.length >= 6 && model.length >= 6 && (model.include?(serial) || serial.include?(model))
    end
  end

  def cues(test_count:)
    @cues ||= {}
    @cues[test_count] ||= build_cues(test_count)
  end

  # Whether this comparison meets the same-owner evidence a future invitation would need.
  # An assessment only: it sends nothing and merges nothing
  def readiness_checks(serial_stolen:, test_count:)
    initials = bikes.map { initial_ownership(it) }
    accounts = initials.map { it&.user_id }
    emails = initials.map { normalized_email(it) }
    separate_cues = cues(test_count:).select { SEPARATE_REVIEW_CUES.include?(it.key) }
    [
      serial_stolen ? Check.new(:blocked, "Stolen history on this whole serial (any record, manufacturer or status) is a hard merge veto") :
        Check.new(:pass, "No stolen report on this whole serial now; recheck when a merge executes"),
      ((bikes.any? { it.deleted_at || it.example || it.likely_spam }) ? Check.new(:blocked, "Includes a deleted, example or spam record") : nil),
      *separate_cues.map { Check.new(:blocked, "#{it.label} — needs separate review, not an invitation") },
      if accounts.compact.size == bikes.size && accounts.uniq.size == 1
        Check.new(:pass, "Same known account on every initial registration")
      elsif emails.compact.size == bikes.size && emails.uniq.size == 1
        Check.new(:uncertain, "Same initial email only — tentative; shops and shared inboxes reuse emails")
      else
        Check.new(:blocked, "Initial contacts differ or are missing — not a same-owner candidate")
      end,
      ((bikes.all? { it.current_ownership&.user_id && it.current_ownership.user_id == accounts.first }) ?
        Check.new(:pass, "Current ownership is that same account on every record") :
        Check.new(:uncertain, "Current ownership is not the same known account on every record")),
      ((initials.any? { claim_status(it) == "Claimed" }) ? Check.new(:pass, "Claimed by the account holder") :
        Check.new(:uncertain, "Never claimed — the email may belong to a shop")),
      ((bikes.size == 2) ? Check.new(:pass, "Exactly two registrations") :
        Check.new(:uncertain, "#{bikes.size} registrations — larger groups need record-by-record review")),
      (differing_fields & ["Manufacturer", "Model", "Year"]).presence&.then { Check.new(:uncertain, "#{it.to_sentence} #{(it.size == 1) ? "differs" : "differ"} between records") },
      ((bikes.any? { transferred?(it) || it.marketplace_listings.any? || it.current_impound_record_id }) ?
        Check.new(:uncertain, "Transfer, marketplace or impound history to preserve — not a simple merge") : nil)
    ].compact
  end

  def readiness(checks)
    return :blocked if checks.any? { it.status == :blocked }

    (checks.any? { it.status == :uncertain }) ? :uncertain : :pass
  end

  private

  def build_cues(test_count)
    emails = initial_emails
    accounts = bikes.filter_map { initial_ownership(it)&.user_id }
    BikeServices::DuplicateReviewCues.cues(serials: bikes.map(&:serial_normalized_no_space).uniq,
      record_count: bikes.size, contact_count: emails.uniq.size, test_count:,
      review_contact_count:, model_match_count:, manufacturer_names:,
      single_contact: [emails, accounts].any? { it.size == bikes.size && it.uniq.size == 1 })
  end

  def normalized_email(ownership)
    return if ownership.nil? || ownership.is_phone

    email = ownership.owner_email.to_s.strip.downcase
    email if email.match?(/\A[^@\s]+@[^@\s]+\z/)
  end
end
