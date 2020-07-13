# This is a stub. It needs to be expanded to include all the notifications that we send to users
# (other than graduated_notifications and parking_notifications, which should include notification functionality)

class Notification < ApplicationRecord
  KIND_ENUM = {
    confirmation_email: 0,
    view_claimed_ticket: 10,
  }.freeze

  belongs_to :user
  belongs_to :appointment

  enum kind: KIND_ENUM

  scope :email_success, -> { where(delivery_status: "email_success") }

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def email_success?; delivery_status == "email_success" end
end
