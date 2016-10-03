FactoryGirl.define do
  factory :creation_state do
    association :bike
    # association :creator, factory: :user
    after(:create) do |creation_state, evaluator|
      creation_state.reload
    end
  end
end
