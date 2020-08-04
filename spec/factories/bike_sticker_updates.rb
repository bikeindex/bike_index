FactoryBot.define do
  factory :bike_sticker_update do
    bike_sticker { FactoryBot.create(:bike_sticker_claimed) }
    user { bike_sticker.user }
    bike { bike_sticker.bike }
  end
end
