# frozen_string_literal: true

module BikeServices::OrgSearch
  extend Functionable

  def email_and_name(bikes, query)
    return bikes unless query.present?

    query_string = "%#{query.strip}%"
    bikes.includes(:current_ownership)
      .where("bikes.owner_email ilike ? OR ownerships.owner_name ilike ?", query_string, query_string)
      .references(:current_ownership)
  end

  def notes(bikes, query, organization)
    return bikes unless query.present?

    query_string = "%#{query.strip}%"
    bikes.joins(:bike_organizations)
      .joins("INNER JOIN ownerships ON ownerships.id = bikes.current_ownership_id")
      .joins("INNER JOIN user_registration_organizations ON user_registration_organizations.organization_id = bike_organizations.organization_id AND user_registration_organizations.user_id = ownerships.user_id AND user_registration_organizations.deleted_at IS NULL")
      .where(bike_organizations: {organization_id: organization.id})
      .where("user_registration_organizations.notes ILIKE ?", query_string)
  end
end
