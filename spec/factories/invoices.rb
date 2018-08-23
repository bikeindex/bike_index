FactoryGirl.define do
  factory :invoice do
    organization { FactoryGirl.create(:organization) }
  end
end
