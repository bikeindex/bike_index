# == Schema Information
#
# Table name: organization_landing_pages
# Database name: primary
#
#  id                :bigint           not null, primary key
#  body              :text
#  enabled           :boolean          default(FALSE), not null
#  organization_slug :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  organization_id   :bigint           not null
#
# Indexes
#
#  index_organization_landing_pages_on_organization_id    (organization_id) UNIQUE
#  index_organization_landing_pages_on_organization_slug  (organization_slug) UNIQUE
#
class OrganizationLandingPage < ApplicationRecord
  # organization_slug is derived, so tracking it would version every organization rename
  has_paper_trail only: %i[body enabled organization_id]

  belongs_to :organization

  validates :organization_id, presence: true, uniqueness: true

  before_validation :set_calculated_attributes

  private

  def set_calculated_attributes
    self.body = body&.strip.presence
    # nil for a deleted organization (paranoia scopes the association), which frees the
    # slug for whichever organization takes it next
    self.organization_slug = organization&.slug
  end
end
