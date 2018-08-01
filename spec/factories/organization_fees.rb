FactoryGirl.define do
  factory :organization_fee do
    organization { FactoryGirl.create(:organization) }
  end
end
