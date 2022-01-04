class UserRegistrationOrganization < ApplicationRecord
  acts_as_paranoid

  belongs_to :user
  belongs_to :organization

  validates_presence_of :user_id, :organization_id

  after_commit :update_associations

  def bikes
    all_bikes? ? user.bikes : user.bikes.organization(organization_id)
  end

  def manages_information?
    registration_info.present? || organization.additional_registration_fields.any?
  end

  # Use all the registration info from the bikes
  def set_initial_registration_info
    reg_info_array = bikes.reorder(:updated_at).map(&:registration_info).reject(&:blank?)
    self.registration_info = reg_info_array.reduce({}, :merge)
  end

  def update_associations
    bikes.each do |bike|
      bike_organization = BikeOrganization.unscoped.where(organization_id: organization_id, bike_id: bike.id).first_or_create
      bike_organization.deleted_at = nil
      bike_organization.can_not_edit_claimed = can_not_edit_claimed
      unless bike.bike_organizations.where(organization_id: organization_id).any?
        bike.bike_organizations.create(organization_id: organization_id, can_not_edit_claimed: can_not_edit_claimed)
      end
      bike.current_ownership&.update(registration_info: registration_info)
    end
  end

  # Because seth wants to have default=false attributes in the database, but can_edit_claimed is easier to think about
  # Duplicates functionality in bike_organization
  def can_edit_claimed
    !can_not_edit_claimed
  end

  def can_edit_claimed=(val)
    self.can_not_edit_claimed = !val
  end
end
