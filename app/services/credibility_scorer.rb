class CredibilityScorer
  BASE_SCORE = 50
  MAX_SCORE = 100

  BADGES = {
    override: {
      pos_registration: 100,
      banned: -100
    },

    creation: {
      no_creator: -10,
      creation_organization_trusted: 20,
      creation_organization_suspicious: -10
    },

    ownership: {
      current_registration_claimed: 10,
      multiple_ownerships: 10,
      registered_this_month: -10,
      registered_1_year_ago: 10,
      registered_2_years_ago: 20,
      registered_3_years_ago: 30,
      registered_5_years_ago: 40
    },

    user: {
      ambassador: 50,
      longtime_user: 10
    },

    misc: {
      has_bike_sticker: 10,
      has_photos: 10
    }
  }.freeze

  def self.all_badges
    BADGES.values.inject(&:merge)
  end

  def self.badge_value(badges_array)
    Array(badges_array).uniq.map { |key| all_badges[key] }.sum
  end

  def initialize(bike)
    @bike = bike
  end

  def badges
  end

  def score
    badge_value = BASE_SCORE + self.class.badge_value(badges)
    return 0 if badge_value < 0
    badge_value > MAX_SCORE ? MAX_SCORE : badge_value
  end

  # def self.banned_user?(bike)
  #   bike.ownerships.any? { |o| o.creator&.banned? || o.user&.banned? }
  # end

  # def self.score_methods(bike)
  #   [
  #     bike.creation_organization.present? ? :creation_organization_score : nil,
  #     bike.ownerships.count > 1 ? bike.ownerships
  #   ].compact
  #   creation_organization_score(bike) +
  #   ownerships_score(bike) +
  #     user_score(bike.creator, bike.creator_id) +
  #     current_owner_score(bike.user)
  # end

  # def self.creation_organization_score(bike)
  #   organization_score(bike.creation_organization, bike.creation_organization_id)
  # end

  # def self.organization_score(organization = nil, organization_id = nil)
  #   organization_id ||= organization&.id
  #   return 0 if organization_id.blank?
  #   organization ||= Organization.unscoped.find(organization_id)
  #   return 50 if organization.ambassador?
  #   return -10 if organization.deleted?
  #   organization.approved? ? 10 : -10
  # end

  # def self.ownerships_score(bike)
  #   0
  # end

  # def self.current_owner_score(user)
  #   return 0 if user.blank?
  #   uscore = user_score(user)
  #   uscore < 0 ? uscore : uscore + 10
  # end

  # def self.user_score(user = nil, user_id = nil)
  #   user_id ||= user&.id
  #   return 0 if user_id.blank?
  #   return -10 if user.blank? # Because user is deleted
  #   return 50 if user.ambassador?
  #   user.organizations.map { |o| organization_score(o) }.max || 0
  # end
end
