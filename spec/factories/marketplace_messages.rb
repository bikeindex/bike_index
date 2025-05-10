FactoryBot.define do
  factory :marketplace_message do
    marketplace_listing { FactoryBot.create(:marketplace_listing) }
    subject { "some subject" }
    body { "Some message body" }
    sender { FactoryBot.create(:user_confirmed) }
    receiver { marketplace_listing.seller }

    trait :reply do
      initial_record { FactoryBot.create(:marketplace_message) }
      marketplace_listing { initial_record.marketplace_listing }
      subject { nil }

      # Only pass in sender - receiver will choose the correct recipient
      sender { initial_record.receiver }
      receiver { (sender_id == initial_record.sender_id) ? initial_record.receiver : initial_record.sender }
    end

    factory :marketplace_message_reply, traits: [:reply]
  end
end
