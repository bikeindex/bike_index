# == Schema Information
#
# Table name: organization_landing_pages
# Database name: primary
#
#  id              :bigint           not null, primary key
#  body            :text
#  enabled         :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :bigint           not null
#
# Indexes
#
#  index_organization_landing_pages_on_organization_id  (organization_id) UNIQUE
#
class OrganizationLandingPage < ApplicationRecord
  has_paper_trail only: %i[body enabled organization_id]

  belongs_to :organization

  validates :organization_id, presence: true, uniqueness: true

  before_validation :set_calculated_attributes

  def self.for(organization)
    where(organization_id: organization.id).first_or_create
  end

  # ORGANIZATIONS_WITH_LANDING_PAGES is what actually routes the page; enabled is a copy of it
  # that only Backfills::OrganizationLandingPageJob reconciles, so the two can drift
  def env_enabled?
    LandingPages::ORGANIZATIONS.include?(organization&.slug)
  end

  def enabled_matches_env?
    enabled? == env_enabled?
  end

  private

  def set_calculated_attributes
    self.body = body&.strip.presence
  end
end
