# == Schema Information
#
# Table name: logged_searches
#
#  id                :bigint           not null, primary key
#  city              :string
#  duration_ms       :integer
#  endpoint          :integer
#  includes_query    :boolean          default(FALSE)
#  ip_address        :string
#  latitude          :float
#  log_line          :text
#  longitude         :float
#  neighborhood      :string
#  page              :integer
#  processed         :boolean          default(FALSE)
#  query_items       :jsonb
#  request_at        :datetime
#  serial_normalized :string
#  stolenness        :integer
#  street            :string
#  zipcode           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  country_id        :bigint
#  organization_id   :bigint
#  request_id        :uuid
#  state_id          :bigint
#  user_id           :bigint
#
class LoggedSearch < AnalyticsRecord
  include Geocodeable

  ENDPOINT_ENUM = {
    web_bikes: 0,
    api_v1_bikes: 1,
    api_v1_stolen_ids: 2,
    api_v1_close_serials: 16,
    api_v2_bikes: 3, # Includes /search, /stolen, /not_stolen
    api_v2_count: 4,
    api_v2_close_serials: 5,
    api_v2_check_if_registered: 17,
    api_v3_bikes: 6,
    api_v3_count: 7,
    api_v3_close_serials: 8,
    api_v3_serials_containing: 9,
    api_v3_external_registries: 10,
    api_v3_check_if_registered: 18,
    admin_bikes: 11,
    org_bikes: 12,
    org_parking_notifications: 13,
    org_impounded: 14,
    org_public_impounded: 15
  }.freeze

  STOLENNESS_ENUM = {all: 0, non: 1, stolen: 2, impounded: 3}.freeze

  # TODO: make the belongs to work across tables
  belongs_to :user
  belongs_to :organization

  enum :endpoint, ENDPOINT_ENUM
  enum :stolenness, STOLENNESS_ENUM, prefix: :stolenness

  validates_presence_of :log_line, :request_at
  validates_uniqueness_of :request_id, allow_nil: false

  scope :organized, -> { where(endpoint: organized_endpoints) }
  scope :serial, -> { where.not(serial_normalized: nil) }
  scope :includes_query, -> { where(includes_query: true) }
  scope :processed, -> { where(processed: true) }
  scope :unprocessed, -> { where(processed: false) }

  def self.organized_endpoints
    %i[org_bikes org_parking_notifications org_impounded].freeze
  end

  def self.endpoints_sym
    ENDPOINT_ENUM.keys.freeze
  end

  def unprocessed?
    !processed
  end

  def should_be_geocoded?
    false # don't geocode automatically, handle it with background job
  end
end
