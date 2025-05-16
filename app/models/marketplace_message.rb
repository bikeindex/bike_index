# == Schema Information
#
# Table name: marketplace_messages
#
#  id                     :bigint           not null, primary key
#  body                   :text
#  kind                   :integer
#  messages_prior_count   :integer
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
  BUYER_SELLER_MESSAGE_KINDS = %w[sender_buyer sender_seller]

  enum :kind, KIND_ENUM

  belongs_to :marketplace_listing
  belongs_to :sender, class_name: "User"
  belongs_to :receiver, class_name: "User"
  belongs_to :initial_record, class_name: "MarketplaceMessage"

  has_many :notifications, as: :notifiable

  validates_presence_of :marketplace_listing_id, :sender_id, :receiver_id, :subject, :body
  validate :users_match_initial_record, if: -> { buyer_seller_message? }

  before_validation :set_calculated_attributes
  after_commit :process_notification

  attr_accessor :skip_processing

  scope :initial_message, -> { where("id = initial_record_id") }
  scope :reply_message, -> { where.not("id = initial_record_id") }
  scope :buyer_seller_message, -> { where(kind: BUYER_SELLER_MESSAGE_KINDS) }
  scope :distinct_threads, -> {
    select("DISTINCT ON (marketplace_messages.initial_record_id) *")
      .order("marketplace_messages.initial_record_id, marketplace_messages.id desc")
  }

  delegate :seller_id, :seller, :item, :item_id, :item_type,
    to: :marketplace_listing, allow_nil: true

  class << self
    def for_user(user)
      where(sender_id: user.id).or(where(receiver_id: user.id))
    end

    def decoded_marketplace_listing_id(user:, id:)
      # marketplace_list_id is encoded as "ml_#{id}"
      return unless id.is_a?(String) && id.start_with?(/ml_/i)

      id.gsub(/\Aml_/i, "")
    end

    def thread_for(user:, id:)
      # marketplace_list_id is encoded as "ml_#{id}"
      if (marketplace_listing_id = decoded_marketplace_listing_id(user:, id:))
        # verify that the marketplace_listing_id exists and the user isn't the seller
        if MarketplaceListing.where.not(seller_id: user.id).where(id: marketplace_listing_id).any?
          return for_user(user).where(marketplace_listing_id:).order(:id)
        end
      else
        matches = for_user(user).where(initial_record_id: id)
        if matches.none?
          # If the id wasn't an initial_record_id, find the record and look up by its initial_record_id
          matches = for_user(user).where(initial_record_id: for_user(user).where(id:).pluck(:initial_record_id))
            .order(:id)
        end
        return matches if matches.any?
      end

      raise ActiveRecord::RecordNotFound
    end

    def threads_for_user(user)
      for_user(user).distinct_threads
    end

    # TODO: permit sending message only in certain period, only to new owner post sale, etc.
    def can_send_message?(marketplace_listing:, user: nil, marketplace_message: nil)
      return false unless can_see_messages?(user:, marketplace_listing:, marketplace_message:)

      marketplace_listing.for_sale? ||
        marketplace_message&.id.present? && marketplace_message.user_ids.include?(user.id)
    end

    def can_see_messages?(marketplace_listing:, user: nil, marketplace_message: nil)
      return false if user.blank?

      if marketplace_message.present?
        return false unless marketplace_message.user_ids.include?(user.id)
        if marketplace_message.initial_record.present?
          return false unless marketplace_message.initial_record.user_ids.include?(user.id)
        end
      elsif marketplace_listing.seller_id == user.id
        return false
      end
      # seller can't send a message unless they have an existing message

      # Block seeing messages for draft posts.
      # TODO: maybe don't allow seeing X days after listing ended?
      %w[for_sale sold removed].include?(marketplace_listing.status)
    end

    # Cached because this is called on every page load, to determine whether to show the messages menu item
    def any_for_user?(user = nil)
      return false unless user.present?

      Rails.cache.fetch(["any_marketplace_messages", user]) { for_user(user).any? }
    end

    def kind_humanized(str)
      str&.to_s&.gsub("sender_", "")
    end
  end

  # Should be called before creation
  def can_send?
    self.class.can_send_message?(user: sender, marketplace_listing:, marketplace_message: self)
  end

  def buyer_seller_message?
    BUYER_SELLER_MESSAGE_KINDS.include?(kind)
  end

  # TODO: do we need all these other_user methods?
  def other_user(user_or_id)
    user_id = user_or_id&.is_a?(User) ? user_or_id.id : user_or_id

    return [receiver, :receiver] if user_id == sender_id
    [sender, :sender] if user_id == receiver_id
  end

  # TODO: do we need all these other_user methods?
  def other_user_and_id(user_or_id)
    user_id = user_or_id&.is_a?(User) ? user_or_id.id : user_or_id

    return [receiver, receiver_id] if user_id == sender_id
    [sender, sender_id] if user_id == receiver_id
  end

  # TODO: do we need all these other_user methods?
  def other_user_display_and_id(user_or_id)
    o_user, o_id = other_user_and_id(user_or_id)

    raise "not passed a sender or receiver: #{user_or_id}" unless o_id.present?

    o_name = o_user&.marketplace_message_name ||
      I18n.t("user_removed", scope: %i[activerecord errors messages])
    [o_name, o_id]
  end

  def initial_message
    initial_record
  end

  def initial_message?
    id.blank? ? initial_record_id.blank? : initial_record_id == id
  end

  def reply_message?
    !initial_message?
  end

  def messages_in_thread
    self.class.where(initial_record_id:)
  end

  def messages_prior
    return self.class.none if initial_message?

    (id.present? ? messages_in_thread.where("id < ?", id) : messages_in_thread).order(:id)
  end

  def user_ids
    [sender_id, receiver_id]
  end

  def email_references_id
    return nil if initial_message?

    er_id = Notification.where(notifiable_type: "MarketplaceMessage", notifiable_id: messages_prior.pluck(:id))
      .with_message_id.order(:id).limit(1).pluck(:message_id).first
    er_id.present? ? "<#{er_id}>" : nil
  end

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  private

  def users_match_initial_record
    # only pertinent for replies, blankness already validated
    return if initial_message? || sender_id.blank? || receiver_id.blank?
    return if initial_record.user_ids.sort == user_ids.sort

    errors.add(:base, I18n.t("user_not_in_initial_record", scope: %i[activerecord errors messages]))
  end

  def set_calculated_attributes
    self.kind ||= (sender_id == seller_id) ? "sender_seller" : "sender_buyer"
    if reply_message?
      self.subject = I18n.t("re", original_subject: initial_record.subject,
        scope: %i[activerecord errors messages])
    end
    self.initial_record ||= self
    self.messages_prior_count ||= messages_prior.count
    self.receiver_id = if initial_message?
      seller_id
    else
      (sender_id == seller_id) ? initial_record.sender_id : seller_id
    end
  end

  def process_notification
    return if skip_processing

    Email::MarketplaceMessageJob.perform_async(id)
  end
end
