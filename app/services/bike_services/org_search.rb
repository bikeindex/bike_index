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
end
