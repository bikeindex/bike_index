FactoryGirl.define do
  factory :bike_organization do
    bike { FactoryGirl.create(:bike) }
    organization { FactoryGirl.create(:organization) }
  end
end
