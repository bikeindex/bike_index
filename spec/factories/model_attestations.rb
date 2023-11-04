FactoryBot.define do
  factory :model_attestation do
    model_audit { FactoryBot.create(:model_audit) }
    kind { :certified_by_manufacturer }
    user { FactoryBot.create(:user) }
  end
end
