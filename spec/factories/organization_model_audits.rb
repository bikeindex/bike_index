FactoryBot.define do
  factory :organization_model_audit do
    organization { FactoryBot.create(:organization) }
    model_audit { FactoryBot.create(:model_audit) }
  end
end
