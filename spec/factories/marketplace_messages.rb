FactoryBot.define do
  factory :marketplace_message do
    marketplace_listing { FactoryBot.create(:marketplace_listing) }
    body { "Some " }
    sender { FactoryBot.create(:user_confirmed) }
    receiver { FactoryBot.create(:user_confirmed) }
    kind { :buyer_to_seller }
  end
end
