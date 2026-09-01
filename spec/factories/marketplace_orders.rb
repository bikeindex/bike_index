FactoryBot.define do
  factory :marketplace_order do
    marketplace_listing { FactoryBot.create(:marketplace_listing, :for_sale) }
    buyer { FactoryBot.create(:user_confirmed) }
    fulfillment_kind { "local_pickup" }

    trait :shipped do
      fulfillment_kind { "shipped" }
      shipping_amount_cents { 9_250 }
      shop_fee_cents { 7_500 }
    end

    trait :paid do
      status { "paid" }
      paid_at { Time.current - 1.hour }
    end
  end
end
