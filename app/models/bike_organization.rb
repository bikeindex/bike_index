# == Schema Information
#
# Table name: bike_organizations
# Database name: primary
#
#  id                   :integer          not null, primary key
#  can_not_edit_claimed :boolean          default(FALSE), not null
#  deleted_at           :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  bike_id              :integer
#  organization_id      :integer
#
# Indexes
#
#  index_bike_organizations_on_bike_id          (bike_id)
#  index_bike_organizations_on_deleted_at       (deleted_at)
#  index_bike_organizations_on_organization_id  (organization_id)
#
class BikeOrganization < ApplicationRecord
  acts_as_paranoid

  belongs_to :bike
  belongs_to :organization

  validates_presence_of :bike_id, :organization_id
  validates_uniqueness_of :organization_id, scope: [:bike_id], allow_nil: false

  scope :can_edit_claimed, -> { where(can_not_edit_claimed: false) }

  def user_registration_organization
    bike.user&.user_registration_organizations&.where(organization_id: organization_id)&.first
  end

  # Could eventually be more sophisticated! Not clear what we'll do
  def overridden_by_user_registration?
    user_registration_organization&.all_bikes?
  end

  # Because seth wants to have default=false attributes in the database, but can_edit_claimed is easier to think about
  def can_edit_claimed
    !can_not_edit_claimed
  end

  def can_edit_claimed=(val)
    self.can_not_edit_claimed = !val
  end
end
