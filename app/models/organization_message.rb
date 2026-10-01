# == Schema Information
#
# Table name: organization_messages
# Database name: primary
#
#  id              :bigint           not null, primary key
#  message         :text
#  receiver_email  :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  bike_id         :bigint           not null
#  organization_id :bigint           not null
#  receiver_id     :bigint
#  sender_id       :bigint           not null
#
# Indexes
#
#  index_organization_messages_on_bike_id          (bike_id)
#  index_organization_messages_on_organization_id  (organization_id)
#  index_organization_messages_on_receiver_id      (receiver_id)
#  index_organization_messages_on_sender_id        (sender_id)
#
# An org member's message to the owner of a bike registered with the org — not a
# StolenNotification, which is contact about a theft
class OrganizationMessage < ApplicationRecord
  belongs_to :bike
  belongs_to :organization
  belongs_to :sender, class_name: "User"
  belongs_to :receiver, class_name: "User"

  has_many :notifications, as: :notifiable

  validates_presence_of :bike, :organization, :sender, :message, :receiver_email
  validate :sender_permitted, on: :create

  before_validation :set_calculated_attributes
  after_create_commit { EmailJobs::OrganizationMessageJob.perform_async(id) }

  def self.for?(bike:, organization:) = unavailable_reason(bike:, organization:).nil?

  # A phone registration's owner_email is the phone number, so there's nothing to email
  def self.unavailable_reason(bike:, organization:)
    if bike.status_stolen?
      :stolen
    elsif !bike.status_with_owner?
      :not_with_owner
    elsif bike.phone_registration?
      :phone_registration
    elsif !bike.organized?(organization)
      :not_registered_with_organization
    end
  end

  private

  def set_calculated_attributes
    return if bike.blank?

    self.receiver ||= bike.user
    self.receiver_email ||= bike.owner_email
  end

  def sender_permitted
    return if bike.blank? || organization.blank?
    return if self.class.for?(bike:, organization:) && bike.contact_owner?(sender, organization)

    errors.add(:base, "sender can't message the owner of this #{bike.type}")
  end
end
