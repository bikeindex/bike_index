FactoryGirl.define do
  factory :creation_state do
    bike { FactoryGirl.create(:bike) }
    creator { FactoryGirl.create(:user) }
  end
end
