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
