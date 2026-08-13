# == Schema Information
#
# Table name: organization_landing_pages
# Database name: primary
#
#  id              :bigint           not null, primary key
#  body            :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :bigint           not null
#
# Indexes
#
#  index_organization_landing_pages_on_organization_id  (organization_id) UNIQUE
#
class OrganizationLandingPage < ApplicationRecord
  has_paper_trail only: %i[body]

  belongs_to :organization

  validates :organization_id, presence: true, uniqueness: true

  before_validation :set_calculated_attributes

  def self.for(organization)
    where(organization_id: organization.id).first_or_create
  end

  def set_calculated_attributes
    self.body = body.presence
  end
end
