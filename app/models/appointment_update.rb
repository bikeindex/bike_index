class AppointmentUpdate < ApplicationRecord
  belongs_to :appointment
  belongs_to :user

  validates_presence_of :appointment_id

  before_create :set_organization_update

  enum status: Appointment::STATUS_ENUM

  scope :organization_update, -> { where(organization_update: true) }
  scope :customer_update, -> { where(organization_update: false) }

  def signed_in_update?; user_id.present? end

  def organization_update?; organization_update end

  def customer_update?; !organization_update? end

  def set_organization_update
    self.organization_update = user.present? && user.member_of?(appointment&.organization)
  end
end
