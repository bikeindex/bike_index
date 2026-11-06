require "did_you_mean/levenshtein"

module BikeDuplicatesServices
  class Review
    ContactGroup = Data.define(:number, :email, :bikes) do
      # Never the email itself
      def as_json(*)
        {number:, email_present: !email.nil?, bike_ids: bikes.map(&:id),
         review_contact: BikeDuplicatesServices::Cues.review_contact?(email)}.as_json
      end
    end
    Check = Data.define(:status, :label)
    # Separate review, never invitation candidates
    SEPARATE_REVIEW_CUES = %w[not_a_serial standard_marking possible_code test_marker review_contact].freeze
    # Finder's same-owner criteria, other than the account and email: what to say when [met, unmet].
    # A nil is nothing worth saying
    SAME_OWNER_LABELS = {
      "two_records" => ["Exactly two registrations", "Not exactly two registrations — larger groups need record-by-record review"],
      "current_owner" => ["Current ownership matches the initial registration on every record", "Current ownership differs from the initial registration on a record"],
      "claimed" => ["A registration is claimed", "Never claimed — the email may belong to a shop"],
      "shop_unclaimed" => [nil, "A shop registration has been claimed"],
      "simple_history" => [nil, "Transfer, marketplace, impound or a status other than with owner to preserve — not a simple merge"],
      "one_model" => [nil, "Model differs between records"],
      "one_year" => [nil, "Year differs between records"],
      "one_manufacturer_other" => [nil, "Custom manufacturer details differ between records"],
      "one_stored_serial" => [nil, "Stored serials differ — normalizing may have joined different numbers"],
      "named_manufacturer" => [nil, "Manufacturer is Other, so it can't corroborate the match"]
    }.freeze

    FIELDS = {
      "Manufacturer" => ->(bike) { [bike.manufacturer&.name, bike.manufacturer_other].compact_blank.join(" ") },
      "Model" => ->(bike) { bike.frame_model },
      "Year" => ->(bike) { bike.year },
      "Primary color" => ->(bike) { bike.primary_frame_color&.name },
      "Vehicle type" => ->(bike) { bike.cycle_type&.humanize },
      "Propulsion" => ->(bike) { bike.propulsion_type&.humanize },
      "Frame size" => ->(bike) { bike.frame_size&.upcase },
      "Stored serial" => ->(bike) { bike.serial_number },
      "Whole normalized serial" => ->(bike) { bike.serial_normalized_no_space },
      "Status" => ->(bike) { bike.status&.humanize }
    }.freeze

    attr_reader :bikes, :reference_bike

    # The first ownership: no previous one, then the earliest
    def self.initial_ownership(bike)
      bike&.ownerships&.min_by { |ownership| [ownership.previous_ownership_id.nil? ? 0 : 1, ownership.created_at || Time.at(0), ownership.id || 0] }
    end

    # bikes: the loaded records, with their ownerships. What else the review needs, it loads once
    def initialize(bikes:, reference_bike: nil)
      @bikes = bikes
      @reference_bike = reference_bike || bikes.first
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
      ownership, reference_ownership = ownership_pair(bike, initial:)
      return "Account unavailable" if ownership&.user_id.nil? || reference_ownership&.user_id.nil?

      (ownership.user_id == reference_ownership.user_id) ? "Same account" : "Different accounts"
    end

    def email_evidence(bike, initial: false)
      email, reference_email = ownership_pair(bike, initial:).map { normalized_email(it) }
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
      return "#{ownership.pos_kind.delete_suffix("_pos").humanize} POS" if pos?(bike)

      ownership&.origin&.humanize
    end

    def organization(bike) = initial_ownership(bike)&.organization || bike.creation_organization

    def transferred?(bike) = bike.ownerships.any?(&:previous_ownership_id)

    def stolen_history?(bike) = bike.status_stolen? || bike.current_stolen_record_id.present? || stolen_count(bike).positive?

    # Every stolen record on the bike, deleted ones included
    def stolen_count(bike) = stolen_record_counts.fetch(bike.id, 0)

    def stolen_records_count = stolen_record_counts.values.sum

    # Stolen history on any record sharing one of these whole serials, whatever its manufacturer
    def serial_stolen?
      return @serial_stolen if defined?(@serial_stolen)

      @serial_stolen = BikeDuplicatesServices::Finder.stolen_serials?(bikes.map(&:serial_normalized_no_space).uniq)
    end

    # Listings on the bike and on its versions, as the queues count them
    def marketplace_count(bike) = marketplace_counts.fetch(bike.id, 0)

    # Private images too, which public_images leaves out
    def photo_count(bike) = photo_counts.fetch(bike.id, 0)

    # The same test-marker rule the dashboard queues use
    def test?(bike) = test_bike_ids.include?(bike.id)

    def test_count = test_bike_ids.size

    def account_email(user_id) = account_emails[user_id]

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
        .filter_map { BikeDuplicatesServices::Cues.not_a_serial(it, manufacturer_names:) }.first
    end

    def initial_emails = @initial_emails ||= bikes.filter_map { normalized_email(initial_ownership(it)) }

    def review_contact_count
      @review_contact_count ||= bikes.count { BikeDuplicatesServices::Cues.review_contact?(normalized_email(initial_ownership(it))) }
    end

    def model_match_count
      bikes.count do |bike|
        serial = bike.serial_normalized_no_space.to_s
        model = SerialNormalizer.no_space(SerialNormalizer.normalized_and_corrected(bike.frame_model)).to_s
        serial.length >= 6 && model.length >= 6 && (model.include?(serial) || serial.include?(model))
      end
    end

    def cues = @cues ||= build_cues

    # Whether this comparison meets the same-owner evidence a future invitation would need.
    # An assessment only: it sends nothing and merges nothing
    def readiness_checks = @readiness_checks ||= build_readiness_checks

    def readiness
      return :blocked if readiness_checks.any? { it.status == :blocked }

      (readiness_checks.any? { it.status == :uncertain }) ? :uncertain : :pass
    end

    private

    def build_readiness_checks
      evidence = BikeDuplicatesServices::Finder.same_owner_evidence(bikes.map(&:id))
      separate_cues = cues.select { SEPARATE_REVIEW_CUES.include?(it.key) }
      serials = bikes.map { it.serial_normalized_no_space.to_s }
      manufacturer_ids = bikes.map(&:manufacturer_id)
      [
        if serial_stolen?
          Check.new(:blocked, "Stolen history on this whole serial (any record, manufacturer or status) is a hard merge veto")
        elsif bikes.any? { stolen_history?(it) }
          Check.new(:blocked, "A record has its own stolen history, a hard merge veto whatever its serial")
        else
          Check.new(:pass, "No stolen history on these records or their whole serials now; recheck when a merge executes")
        end,
        ((serials.uniq.size == 1 && serials.first.length >= 6) ? Check.new(:pass, "Same whole normalized serial on every record") :
          Check.new(:blocked, "Whole normalized serials differ, or one is missing or shorter than 6 characters")),
        ((manufacturer_ids.uniq.size == 1 && manufacturer_ids.first) ? Check.new(:pass, "Same manufacturer on every record") :
          Check.new(:blocked, "Manufacturers differ, or one is missing")),
        ((bikes.any? { it.deleted_at || it.example || it.likely_spam }) ? Check.new(:blocked, "Includes a deleted, example or spam record") : nil),
        *separate_cues.map { Check.new(:blocked, "#{it.label} — needs separate review, not an invitation") },
        if evidence["one_account"] && evidence["one_email"]
          Check.new(:pass, "Same known account and email on every initial registration")
        elsif evidence["one_account"]
          Check.new(:uncertain, "Same known account, but the initial emails differ or one is missing")
        elsif evidence["one_email"]
          Check.new(:uncertain, "Same initial email only — tentative; shops and shared inboxes reuse emails")
        else
          Check.new(:blocked, "Initial contacts differ or are missing — not a same-owner candidate")
        end,
        *SAME_OWNER_LABELS.filter_map do |criterion, (met, unmet)|
          evidence.fetch(criterion) ? (met && Check.new(:pass, met)) : Check.new(:uncertain, unmet)
        end
      ].compact
    end

    def build_cues
      emails = initial_emails
      accounts = bikes.filter_map { initial_ownership(it)&.user_id }
      BikeDuplicatesServices::Cues.cues(serials: bikes.map(&:serial_normalized_no_space).uniq, entered_serials: bikes.map(&:serial_number),
        record_count: bikes.size, contact_count: emails.uniq.size, test_count:,
        review_contact_count:, model_match_count:, manufacturer_names:, shop_default_propulsion: shop_default_propulsion?,
        single_contact: [emails, accounts].any? { it.size == bikes.size && it.uniq.size == 1 })
    end

    def pos?(bike) = BikeDuplicatesServices::Finder::POS_KINDS.include?(initial_ownership(bike)&.pos_kind)

    def ownership_pair(bike, initial:) = [bike, reference_bike].map { initial ? initial_ownership(it) : it&.current_ownership }

    # Cues.fetch_manufacturer_name_serials, so a brand typed as the serial is caught
    def manufacturer_names = @manufacturer_names ||= BikeDuplicatesServices::Cues.fetch_manufacturer_name_serials

    def stolen_record_counts
      @stolen_record_counts ||= StolenRecord.unscoped.where(bike_id: bikes.map(&:id)).group(:bike_id).count
    end

    def marketplace_counts
      @marketplace_counts ||= MarketplaceListing.where(item_type: "Bike", item_id: bikes.map(&:id)).group(:item_id).count
        .merge(MarketplaceListing.where(item_type: "BikeVersion").joins("INNER JOIN bike_versions ON bike_versions.id = marketplace_listings.item_id")
          .where(bike_versions: {bike_id: bikes.map(&:id)}).group("bike_versions.bike_id").count) { |_bike_id, direct, versions| direct + versions }
    end

    def photo_counts
      @photo_counts ||= PublicImage.unscoped.where(imageable_type: "Bike", imageable_id: bikes.map(&:id)).group(:imageable_id).count
    end

    def test_bike_ids = @test_bike_ids ||= BikeDuplicatesServices::Finder.test_bike_ids(bikes.map(&:id)).to_set

    def account_emails
      @account_emails ||= User.unscoped.where(id: bikes.flat_map { it.ownerships.map(&:user_id) }.compact.uniq).pluck(:id, :email).to_h
    end

    def shop_default_propulsion?
      shop_default_at = bikes.select { pos?(it) && it.propulsion_type == "foot-pedal" }.map(&:created_at).min
      shop_default_at && bikes.any? { !pos?(it) && it.created_at > shop_default_at && PropulsionType.motorized?(it.propulsion_type) }
    end

    def normalized_email(ownership)
      return if ownership.nil? || ownership.is_phone

      email = ownership.owner_email.to_s.strip.downcase
      email if email.match?(/\A[^@\s]+@[^@\s]+\z/)
    end
  end
end
