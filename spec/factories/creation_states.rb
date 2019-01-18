FactoryBot.define do
  factory :creation_state do
    bike { FactoryBot.create(:bike) }
    creator { FactoryBot.create(:user) }
  end
end
