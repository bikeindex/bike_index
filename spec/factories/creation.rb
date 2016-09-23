FactoryGirl.define do
  factory :creation do
    association :creator, factory: :user
  end
end
