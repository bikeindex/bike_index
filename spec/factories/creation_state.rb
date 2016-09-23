FactoryGirl.define do
  factory :creation_state do
    association :creator, factory: :user
  end
end
