FactoryBot.define do
  factory :bike_version do
    bike { FactoryBot.create(:bike, :with_ownership_claimed) }
    owner { bike.owner }
  end
end
