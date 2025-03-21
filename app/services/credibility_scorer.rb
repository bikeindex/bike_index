class CredibilityScorer
  BASE_SCORE = 50
  MAX_SCORE = 100
  CHECK_SUSPISCIOUS_NUMBERS = true # Causes flaky specs, so enable stubbing

  BADGES = {
    overrides: {
      created_at_point_of_sale: 100,
      example_bike: -100,
      user_banned: -200
    },

    creation: {
      created_this_month: -10,
      creation_organization_trusted: 30,
      creation_organization_suspicious: -10,
      creation_organization_spam_registrations: -20,
      likely_spam: -70,
      long_time_registration: 10,
      no_creator: -10
    },

    ownership: {
      current_ownership_claimed: 10,
      multiple_ownerships: 10
    },

    user: {
      long_time_user: 10,
      user_ambassador: 50,
      user_connected_to_strava: 10,
      user_verified_phone: 10,
      user_handle_suspicious: -20,
      user_has_bike_recovered: 10,
      user_sent_in_bike_tip: 10,
      user_supporter: 20,
      user_trusted_organization_role: 30
    },

    bike: {
      has_bike_sticker: 10,
      has_photos: 10,
      serial_duplicated: -20,
      serial_missing: -10
    }
  }.freeze

  def self.all_badges
    BADGES.values.inject(&:merge)
  end

  def self.permitted_badges_array(badges_array)
    badges_array = Array(badges_array)
    return %i[example_bike] if badges_array.include?(:example_bike)
    if (badges_array & %i[user_ambassador creation_organization_trusted]).count == 2
      badges_array -= [:creation_organization_trusted]
    end
    if (badges_array & %i[user_trusted_organization_role creation_organization_trusted]).count == 2
      badges_array -= [:user_trusted_organization_role]
    end
    badges_array
  end

  def self.permitted_badges_hash(badges_array)
    all_badges.slice(*permitted_badges_array(badges_array)).sort_by { |_badge, value| value }.to_h
  end

  def self.badge_value(badges_array)
    permitted_badges_hash(badges_array).map { |badge, value| value }.sum
  end

  def self.creation_badges(ownership = nil, bike = nil)
    return [] unless ownership.present?
    return [:example_bike] if bike&.example?
    return [:created_at_point_of_sale] if ownership.pos?
    c_badges = [creation_age_badge(bike || ownership.bike)].compact
    c_badges << :no_creator if ownership.creator.blank?
    c_badges << :likely_spam if bike&.likely_spam?
    if ownership.organization_id.present?
      organization = Organization.unscoped.find_by_id(ownership.organization_id)
      return [:created_at_point_of_sale] if organization&.does_not_need_pos?
      c_badges << :creation_organization_suspicious if organization_suspicious?(organization)
      if ownership.origin == "embed" && organization.spam_registrations?
        unless bike&.likely_spam?
          c_badges << :creation_organization_spam_registrations
        end
      elsif organization_trusted?(organization)
        c_badges << :creation_organization_trusted
      end
    end
    c_badges
  end

  def self.ownership_badges(bike)
    return [] unless bike.current_ownership.present?
    [
      (bike.ownerships.count > 1) ? :multiple_ownerships : nil,
      bike.claimed? ? :current_ownership_claimed : nil
    ].compact
  end

  def self.bike_user_badges(bike)
    users = relevant_bike_ownership_users(bike)
    badges = users.map { |u| user_badges(u) }.flatten.uniq
    return [:user_banned] if badges.include?(:user_banned)
    return [:user_ambassador] if badges.include?(:user_ambassador)
    badges
  end

  def self.bike_badges(bike)
    [
      bike.serial_unknown? ? :serial_missing : nil,
      bike.duplicate_bikes.any? ? :serial_duplicated : nil,
      bike.public_images.any? ? :has_photos : nil,
      bike.bike_stickers.any? ? :has_bike_sticker : nil
    ].compact
  end

  def self.user_badges(user)
    return [] unless user.present?
    return [:user_banned] if user.banned
    return [:user_ambassador] if user.ambassador?
    badges = []
    badges += [:user_trusted_organization_role] if user.organizations.any? { |o| organization_trusted?(o) }
    badges += [:user_has_bike_recovered] if user.recovered_records.limit(1).present?
    badges += [:user_sent_in_bike_tip] if Feedback.where(user_id: user.id).stolen_tip.any?
    badges += [:user_supporter] if user.payments.any?
    badges += [:long_time_user] if user.created_at < Time.current - 2.years
    badges += [:user_connected_to_strava] if user.integrations.strava.any?
    badges += [:user_verified_phone] if user.phone_confirmed?
    # Don't mark suspicious if we trust them
    unless (badges & %i[user_trusted_organization_role]).any?
      badges += [:user_handle_suspicious] if [user.name, user.username, user.email].any? { |str| suspiscious_handle?(str) }
    end
    badges
  end

  # This badge is displayed on the organization show page
  def self.organization_suspicious?(organization)
    return true if organization.blank? || organization.deleted?
    !organization.approved
  end

  # This badge is displayed on the organization show page
  def self.organization_trusted?(organization)
    return false unless organization.present?
    return true if organization.paid?
    %w[other_pos lightspeed_pos ascend_pos does_not_need_pos].include?(organization.manual_pos_kind)
  end

  #
  # Internal methods for badges below here. Probably should be private?
  # TODO: Figure out a better structure for this
  #

  def self.creation_age_badge(obj)
    return :long_time_registration if obj.created_at < Time.current - 1.year
    (obj.created_at > Time.current - 1.month) ? :created_this_month : nil
  end

  def self.suspiscious_handle?(str)
    return false unless str.present?
    str = str.downcase.strip
    return true if str.match?("thief")
    return false if str.match?(/@.*\.edu/)
    return true if str.match?("5150") && CHECK_SUSPISCIOUS_NUMBERS
    return true if str.match?("shady")
    return true if BadWordCleaner.clean(str).count("*") > str.count("*")
    str.length < 4
  end

  def self.relevant_bike_ownership_users(bike)
    bike.ownerships.map do |ownership|
      # organizations with "does_not_need_pos" regularly register bikes using embed, for customers
      # But for most orgs, embed means anyone could have registered it
      if ownership.origin == "embed" && ownership.pos_kind != "does_not_need_pos"
        [ownership.user]
      else
        [ownership.creator, ownership.user]
      end
    end.flatten.reject(&:blank?).uniq
  end

  def self.humanize_badge(badge)
    if badge == :example_bike
      "Test bike"
    else
      badge.to_s.humanize
    end
  end

  def initialize(bike)
    @bike = bike
  end

  def badges
    self.class.permitted_badges_array(calculated_badges)
  end

  def score
    badge_value = BASE_SCORE + self.class.badge_value(badges)
    return 0 if badge_value < 0
    (badge_value > MAX_SCORE) ? MAX_SCORE : badge_value
  end

  private

  def calculated_badges
    self.class.creation_badges(@bike.current_ownership, @bike) +
      self.class.ownership_badges(@bike) +
      self.class.bike_user_badges(@bike) +
      self.class.bike_badges(@bike)
  end
end
