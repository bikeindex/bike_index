class UserRegistrationOrganization < ApplicationRecord
  acts_as_paranoid

  belongs_to :user
  belongs_to :organization

  validates_presence_of :user_id, :organization_id

  before_validation :set_calculated_attributes
  after_commit :update_associations

  scope :paid_organizations, -> { includes(:organization).where(organizations: {is_paid: true}) }
  scope :not_paid_organizations, -> { includes(:organization).where(organizations: {is_paid: false}) }

  attr_accessor :skip_update

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

  # Because seth wants to have default=false attributes in the database, but can_edit_claimed is easier to think about
  # Duplicates functionality in bike_organization
  def can_edit_claimed
    !can_not_edit_claimed
  end

  def can_edit_claimed=(val)
    self.can_not_edit_claimed = !val
  end

  def set_calculated_attributes
    self.registration_info ||= {}
  end

  def update_associations
    create_missing_bike_organizations
    return true if skip_update
    AfterUserChangeWorker.perform_async(user_id)
  end

  private

  def create_missing_bike_organizations
    bikes.each do |bike|
      bike_organization = BikeOrganization.unscoped.where(organization_id: organization_id, bike_id: bike.id).first_or_create
      bike_organization.deleted_at = nil
      bike_organization.can_not_edit_claimed = can_not_edit_claimed
      unless bike.bike_organizations.where(organization_id: organization_id).any?
        bike.bike_organizations.create(organization_id: organization_id, can_not_edit_claimed: can_not_edit_claimed)
      end
    end
  end
end
