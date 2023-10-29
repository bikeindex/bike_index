class LoggedSearch < AnalyticsRecord
  ENDPOINT_ENUM = {
    web_bikes: 0,
    api_v1_bikes: 1,
    api_v1_stolen_ids: 2,
    api_v1_close_serials: 16,
    api_v2_bikes: 3, # Includes /search, /stolen, /not_stolen
    api_v2_count: 4,
    api_v2_close_serials: 5,
    api_v3_bikes: 6,
    api_v3_count: 7,
    api_v3_close_serials: 8,
    api_v3_serials_containing: 9,
    api_v3_external_registries: 10,
    admin_bikes: 11,
    org_bikes: 12,
    org_parking_notifications: 13,
    org_impounded: 14,
    org_public_impounded: 15
  }.freeze

  STOLENNESS_ENUM = {all: 0, non: 1, stolen: 2, impounded: 3}.freeze

  # TODO: make the belongs to work across tables
  # belongs_to :user
  # belongs_to :organization

  enum endpoint: ENDPOINT_ENUM
  enum stolenness: STOLENNESS_ENUM, _prefix: :stolenness

  validates_presence_of :log_line, :request_at
  validates_uniqueness_of :request_id, allow_nil: false

  scope :organized, -> { where(endpoint: organized_endpoints) }
  scope :serial, -> { where.not(serial_normalized: nil) }
  scope :includes_query, -> { where(includes_query: true) }

  def self.organized_endpoints
    %i[org_bikes org_parking_notifications org_impounded].freeze
  end

  def self.endpoints_sym
    ENDPOINT_ENUM.keys.freeze
  end
end
