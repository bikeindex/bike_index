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
FactoryBot.define do
  factory :marketplace_message do
    marketplace_listing { FactoryBot.create(:marketplace_listing, :for_sale) }
    subject { "some subject" }
    body { "Some message body" }
    sender { FactoryBot.create(:user_confirmed) }

    trait :reply do
      # enable passing in the receiver to this factory
      initial_record do
        if receiver || receiver_id.present?
          FactoryBot.create(:marketplace_message, sender: receiver)
        else
          FactoryBot.create(:marketplace_message)
        end
      end

      # enable passing in the receiver to this factory
      sender do
        if receiver || receiver_id.present?
          initial_record.other_user(receiver || receiver_id)&.first
        else
          initial_record.receiver
        end
      end

      marketplace_listing { initial_record.marketplace_listing }
      subject { nil }
    end

    factory :marketplace_message_reply, traits: [:reply]
  end
end
