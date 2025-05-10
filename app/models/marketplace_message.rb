# == Schema Information
#
# Table name: marketplace_messages
#
#  id                     :bigint           not null, primary key
#  body                   :text
#  kind                   :integer
#  subject                :text
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  initial_record_id      :bigint
#  marketplace_listing_id :bigint
#  receiver_id            :bigint
#  sender_id              :bigint
#
# Indexes
#
#  index_marketplace_messages_on_initial_record_id       (initial_record_id)
#  index_marketplace_messages_on_marketplace_listing_id  (marketplace_listing_id)
#  index_marketplace_messages_on_receiver_id             (receiver_id)
#  index_marketplace_messages_on_sender_id               (sender_id)
#
class MarketplaceMessage < ApplicationRecord
  # enum because eventually may have notifications about sale or alerts about suspicious behavior
  KIND_ENUM = {sender_buyer: 0, sender_seller: 1}.freeze

  enum :kind, KIND_ENUM

  belongs_to :marketplace_listing
  belongs_to :sender, class_name: "User"
  belongs_to :receiver, class_name: "User"
  belongs_to :initial_record, class_name: "MarketplaceMessage"

  has_many :notifications, as: :notifiable

  validates_presence_of :marketplace_listing_id, :sender_id, :receiver_id, :subject

  before_validation :set_calculated_attributes
  after_commit :process_notification

  attr_accessor :skip_processing

  scope :initial_message, -> { where(initial_record_id: nil) }
  scope :reply_message, -> { where.not(initial_record_id: nil) }

  delegate :seller_id, to: :marketplace_listing, allow_nil: true

  class << self
    def for_user(user)
      where(sender_id: user.id).or(where(receiver_id: user.id))
    end

    # Cached because this is called on every page load - to determine whether to render the messages menu item
    def any_for_user?(user = nil)
      return false unless user.present?

      Rails.cache.fetch(["any_marketplace_messages", user]) { for_user(user).any? }
    end
  end

  def initial_message
    initial_message? ? self : initial_record
  end

  def initial_message?
    initial_record_id.blank?
  end

  def reply_message?
    !initial_message?
  end

  private

  def set_calculated_attributes
    self.kind ||= sender_id == seller_id ? "sender_seller" : "sender_buyer"
    self.subject = "Re: #{initial_record.subject}" if reply_message?
  end

  def process_notification
    return if skip_processing

    # ProcessMarketplaceMessageJob
    # Bust caches on the associations
    sender&.update(updated_at: Time.current)
    receiver&.update(updated_at: Time.current)
  end
end
