FactoryBot.define do
  factory :user_alert do
    user { FactoryBot.create(:user_confirmed) }
    kind { UserAlert.kinds.first }
    factory :user_alert_stolen_bike_without_location do
      kind { "stolen_bike_without_location" }
      bike do
        FactoryBot.create(:bike,
          :with_ownership_claimed,
          :with_stolen_record,
          user: user,
          latitude: nil,
          longitude: nil)
      end
    end
  end
end
