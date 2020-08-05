class CredibilityScorer
  BASE_SCORE = 50
  MAX_SCORE = 100

  def self.score(bike)
    return MAX_SCORE if bike.pos?
    return 0 if bike.ownerships.any? { |o| o.creator&.banned? || o.user&.banned? }
    score_result = BASE_SCORE +
      creation_organization_score(bike) +
      ownerships_score(bike) +
      user_score(bike.creator, bike.creator_id) +
      current_owner_score(bike.user)

    return 0 if score_result < 0
    score_result > MAX_SCORE ? MAX_SCORE : score_result
  end

  def self.creation_organization_score(bike)
    organization_score(bike.creation_organization, bike.creation_organization_id)
  end

  def self.organization_score(organization = nil, organization_id = nil)
    organization_id ||= organization&.id
    return 0 if organization_id.blank?
    organization ||= Organization.unscoped.find(organization_id)
    return 50 if organization.ambassador?
    return -10 if organization.deleted?
    organization.approved? ? 10 : -10
  end

  def self.ownerships_score(bike)
    0
  end

  def self.current_owner_score(user)
    return 0 if user.blank?
    uscore = user_score(user)
    uscore < 0 ? uscore : uscore + 10
  end

  def self.user_score(user = nil, user_id = nil)
    user_id ||= user&.id
    return 0 if user_id.blank?
    return -10 if user.blank? # Because user is deleted
    return -1000 if user.banned
    return 50 if user.ambassador?
    user.organizations.map { |o| organization_score(o) }.max || 0
  end
end
