FactoryBot.define do
  factory :ambassador, class: Ambassador, parent: :organized_user do
    transient do
      organization { FactoryBot.create(:organization_ambassador) }
    end
    after(:create) do |ambassador, evaluator|
      FactoryBot.create(:membership_ambassador,
                        user: ambassador,
                        organization: evaluator.organization)
    end
  end
end
