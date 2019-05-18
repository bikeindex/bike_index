FactoryBot.define do
  factory :ambassador, class: Ambassador, parent: :user_confirmed do
    after(:create) do |ambassador, _evaluator|
      FactoryBot.create(:membership_ambassador, user: ambassador)
    end
  end
end
