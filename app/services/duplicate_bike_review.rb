require "did_you_mean/levenshtein"

class DuplicateBikeReview
  attr_reader :bikes, :reference_bike

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
    return if bike.nil?

    bike.ownerships.min_by { |ownership| [ownership.previous_ownership_id.nil? ? 0 : 1, ownership.created_at || Time.at(0), ownership.id || 0] }
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

  private

  def normalized_email(ownership)
    return if ownership.nil? || ownership.is_phone

    email = ownership.owner_email.to_s.strip.downcase
    email if email.match?(/\A[^@\s]+@[^@\s]+\z/)
  end
end
