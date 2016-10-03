FactoryGirl.define do
  factory :creation_state do
    association :bike
    # association :creator, factory: :user
  end
end
