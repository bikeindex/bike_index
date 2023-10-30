FactoryBot.define do
  factory :model_attestation do
    model_tracker { FactoryBot.create(:model_tracker) }
    kind { :certified_by_manufacturer }
    user { FactoryBot.create(:user) }
  end
end
