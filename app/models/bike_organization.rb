class BikeOrganization < ApplicationRecord
  belongs_to :bike
  belongs_to :organization
  validates_presence_of :bike_id, :organization_id
  validates_uniqueness_of :organization_id, scope: [:bike_id], allow_nil: false
  acts_as_paranoid

  scope :can_edit_claimed, -> { where(can_not_edit_claimed: false) }

  # Because seth wants to have default=false attributes in the database, but can_edit_claimed is easier to think about
  def can_edit_claimed; !can_not_edit_claimed end

  def can_edit_claimed=(val)
    self.can_not_edit_claimed = !val
  end
end
