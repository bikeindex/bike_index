# == Schema Information
#
# Table name: marketplace_messages
#
#  id                     :bigint           not null, primary key
#  body                   :text
#  kind                   :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  marketplace_listing_id :bigint
#  receiver_id            :bigint
#  sender_id              :bigint
#
# Indexes
#
#  index_marketplace_messages_on_marketplace_listing_id  (marketplace_listing_id)
#  index_marketplace_messages_on_receiver_id             (receiver_id)
#  index_marketplace_messages_on_sender_id               (sender_id)
#
class MarketplaceMessage < ApplicationRecord
  KIND_ENUM = {buyer_to_seller: 0, seller_response: 1}.freeze

  enum :kind, KIND_ENUM

  belongs_to :marketplace_listing
  belongs_to :sender, class_name: "User"
  belongs_to :receiver, class_name: "User"

  has_many :notifications, as: :notifiable


end
