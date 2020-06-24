class AppointmentUpdate < ApplicationRecord
  belongs_to :appointment
  belongs_to :user

  validates_presence_of :appointment_id

  enum status: Appointment::STATUS_ENUM
  enum creator_type: Appointment::CREATOR_TYPE_ENUM
end
