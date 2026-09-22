# frozen_string_literal: true

# == Schema Information
#
# Table name: bike_flights_requests
# Database name: primary
#
#  id              :bigint           not null, primary key
#  duration_ms     :integer
#  error_message   :string
#  kind            :integer          not null
#  path            :string
#  request_body    :jsonb
#  response_body   :jsonb
#  response_status :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Every request Integrations::BikeFlights::Client makes, kept for reconciling orders and labels
# against what BikeFlights charged. Login's credentials and token are never stored.
class BikeFlightsRequest < ApplicationRecord
  KIND_ENUM = {
    login: 0,
    shop_rate: 1,
    create_order: 2,
    create_label: 3,
    label: 4,
    package_location: 5,
    countries: 6
  }.freeze

  enum :kind, KIND_ENUM
end
