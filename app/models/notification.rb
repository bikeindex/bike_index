# This is a stub. It needs to be expanded to include all the notifications that we send to users
# (other than graduated_notifications and parking_notifications, which should include notification functionality)

class Notification < ApplicationRecord
  KIND_ENUM = {
    confirmation_email: 0,
    view_appointment: 10,
  }.freeze

  belongs_to :user
  belongs_to :appointment

  enum kind: KIND_ENUM

  after_commit :send_notification, on: [:create]

  scope :email_success, -> { where(delivery_status: "email_success") }

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  # Eventually additional logic - like whether to create, because duplicates, etc - will be included here
  def self.create_for(kind, **kwargs)
    notification = new(kind: kind)
    notification.appointment = kwargs.delete(:appointment) if kwargs.key?(:appointment)
    notification.appointment_id = kwargs.delete(:appointment_id) if kwargs.key?(:appointment_id)
    notification.save
  end

  def email_success?; delivery_status == "email_success" end

  def send_notification
    return true if kind == "confirmation_email" # email for this is managed outside of this class, at least for now
    SendNotificationWorker.perform_async(id)
  end
end
