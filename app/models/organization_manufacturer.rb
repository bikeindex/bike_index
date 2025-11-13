# == Schema Information
#
# Table name: organization_manufacturers
# Database name: primary
#
#  id              :bigint           not null, primary key
#  can_view_counts :boolean          default(FALSE)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  manufacturer_id :bigint
#  organization_id :bigint
#
# Indexes
#
#  index_organization_manufacturers_on_manufacturer_id  (manufacturer_id)
#  index_organization_manufacturers_on_organization_id  (organization_id)
#
class OrganizationManufacturer < ApplicationRecord
  belongs_to :organization
  belongs_to :manufacturer

  validates :manufacturer_id, presence: true
  validates :organization_id, presence: true, uniqueness: {scope: [:manufacturer_id]}

  scope :can_view_counts, -> { where(can_view_counts: true) }

  def manufacturer_organization
    Organization.where(manufacturer_id: manufacturer_id).first
  end
end
