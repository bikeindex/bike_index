module SpamEstimator
  module Bike
    extend Functionable

    MARK_SPAM_PERCENT = 90 # May modify in the future!

    def estimate(bike, stolen_record = nil)
      estimate = 0
      return estimate if bike.blank?
      # serial_number isn't in cached_data, and it's the most common injection target
      return 100 if Text.looks_malicious?(bike.cached_data) || Text.looks_malicious?(bike.serial_number)

      estimate += 35 if bike.creation_organization&.spam_registrations
      estimate += 0.2 * Text.estimate(bike.frame_model)
      estimate += 0.4 * Text.estimate(bike.manufacturer_other)
      estimate += 50 if low_entropy_fingerprint?(bike)
      estimate += domain_estimate(bike.owner_email)
      estimate += estimate_stolen_record(stolen_record || bike.current_stolen_record)

      estimate.clamp(0, 100)
    end

    #
    # private below here
    #

    # Bots reuse one junk value across every field; matching 1-2 char fields are probably not a real bike
    def low_entropy_fingerprint?(bike)
      fields = [bike.serial_number, bike.frame_model, bike.manufacturer_other]
        .map { |value| value&.strip&.downcase }
      return false if fields.any?(&:blank?)

      fields.uniq.one? && fields.first.length <= 2
    end

    def reserved_email_domain?(email)
      domain = email&.split("@")&.last&.strip
      return false if domain.blank?

      domain.match?(EmailDomain::RESERVED_REGEX)
    end

    def domain_estimate(email)
      return 0 unless EmailDomain::VERIFICATION_ENABLED
      # RFC-reserved domains (e.g. example.com) are never a real registrant
      return 100 if reserved_email_domain?(email)

      email_domain = EmailDomain.find_or_create_for(email)

      return 0 if email_domain.blank? || email_domain.permitted?

      # If it's banned, it's spam - otherwise increase spam likelihood (pending_ban)
      email_domain.banned? ? 100 : 40
    end

    def estimate_stolen_record(stolen_record)
      estimate = 0
      return 0 if stolen_record.blank?

      estimate += Text.estimate(stolen_record.theft_description)
      if stolen_record.street.present?
        street_letters = stolen_record.street.gsub(/[^a-z|\s]/, "") # Ignore non letter things from street
        estimate += 0.3 * Text.estimate(street_letters)
      end
      (estimate - 20).clamp(0, 100)
    end

    conceal :low_entropy_fingerprint?, :reserved_email_domain?, :domain_estimate, :estimate_stolen_record
  end
end
