class ModelTracker < ApplicationRecord
  CERTIFICATION_STATUS_ENUM = {
    uncertified: 0,
    certified_by_trusted_org: 1,
    certified_by_manufacturer: 2,
  }.freeze

  enum certification_status: CERTIFICATION_STATUS_ENUM
  enum propulsion_type: PropulsionType::SLUGS

  has_many :bikes
end
