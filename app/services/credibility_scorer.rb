class CredibilityScorer
  BASE_SCORE = 50
  MAX_SCORE = 100

  BADGES = {
    overrides: {
      created_by_point_of_sale: 100,
      user_banned: -200
    },

    creation: {
      no_creator: -10,
      creation_organization_trusted: 20,
      creation_organization_suspicious: -10,
      created_this_month: -10,
      created_1_year_ago: 10,
      created_2_years_ago: 20,
      created_3_years_ago: 30,
      created_5_years_ago: 40
    },

    ownership: {
      current_ownership_claimed: 10,
      multiple_ownerships: 10
    },

    user: {
      user_ambassador: 50,
      user_trusted_organization_member: 20,
      user_veteran: 10,
      user_connected_to_strava: 10,
      user_handle_suspicious: -20
    },

    bike: {
      serial_missing: -10,
      serial_duplicated: -20,
      has_bike_sticker: 10,
      has_photos: 10
    }
  }.freeze

  def self.all_badges
    BADGES.values.inject(&:merge)
  end

  def self.permitted_badges_array(badges_array)
    badges_array = Array(badges_array)
    if (badges_array & %i[user_ambassador creation_organization_trusted]).count == 2
      badges_array -= [:creation_organization_trusted]
    end
    if (badges_array & %i[user_trusted_organization_member creation_organization_trusted]).count == 2
      badges_array -= [:user_trusted_organization_member]
    end
    badges_array
  end

  def self.permitted_badges_hash(badges_array)
    all_badges.slice(*permitted_badges_array(badges_array)).sort_by { |_badge, value| value }.to_h
  end

  def self.badge_value(badges_array)
    permitted_badges_hash(badges_array).map { |badge, value| value }.sum
  end

  def self.creation_badges(creation_state = nil)
    return [] unless creation_state.present?
    return [:created_by_point_of_sale] if creation_state.is_pos
    c_badges = [creation_age_badge(creation_state)].compact
    c_badges << :no_creator if creation_state.creator.blank?
    if creation_state.organization_id.present?
      c_badges << :creation_organization_suspicious if organization_suspicious?(creation_state.organization)
      c_badges << :creation_organization_trusted if organization_trusted?(creation_state.organization)
    end
    c_badges
  end

  def self.ownership_badges(bike)
    return [] unless bike.current_ownership.present?
    [
      bike.ownerships.count > 1 ? :multiple_ownerships : nil,
      bike.claimed? ? :current_ownership_claimed : nil
    ].compact
  end

  def self.bike_user_badges(bike)
    users = bike.ownerships.map { |o| [o.creator, o.user] }.flatten.reject(&:blank?).uniq
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
    return [:user_trusted_organization_member] if user.organizations.any? { |o| organization_trusted?(o) }
    badges = []
    badges += [:user_veteran] if user.created_at < Time.current - 2.years
    badges += [:user_connected_to_strava] if user.integrations.strava.any?
    badges += [:user_handle_suspicious] if [user.name, user.username, user.email].any? { |str| suspiscious_handle?(str) }
    badges
  end

  #
  # Individual methods for badges below here. Maybe should be private?
  # TODO: Figure out a better structure for this
  #

  def self.creation_age_badge(obj)
    if obj.created_at > Time.current - 1.year
      obj.created_at > Time.current - 1.month ? :created_this_month : nil
    elsif obj.created_at > Time.current - 2.years
      :created_1_year_ago
    elsif obj.created_at > Time.current - 3.years
      :created_2_years_ago
    elsif obj.created_at > Time.current - 5.years
      :created_3_years_ago
    else
      :created_5_years_ago
    end
  end

  def self.organization_suspicious?(organization)
    return true if organization.blank?
    !organization.approved
  end

  def self.organization_trusted?(organization)
    return false unless organization.present?
    organization.paid? || organization.bike_shop? && organization.does_not_need_pos?
  end

  def self.suspiscious_handle?(str)
    return false unless str.present?
    str = str.downcase.strip
    return true if str.match?("thief")
    return false if str.match?(/@.*\.edu/)
    return true if str.match?("5150") || str.match?("shady")
    return true if BadWordCleaner.clean(str).count("*") > str.count("*")
    str.length < 4
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
    badge_value > MAX_SCORE ? MAX_SCORE : badge_value
  end

  private

  def calculated_badges
    self.class.creation_badges(@bike.creation_state) +
      self.class.ownership_badges(@bike) +
      self.class.bike_user_badges(@bike) +
      self.class.bike_badges(@bike)
  end
end
