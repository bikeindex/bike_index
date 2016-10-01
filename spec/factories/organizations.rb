FactoryGirl.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    short_name { name }
    slug
    available_invitation_count 5
    # before(:create) { |organization| organization.short_name ||= organization.name }
    factory :organization_with_auto_user do
      association :auto_user, factory: :user
      after(:create) do |organization|
        FactoryGirl.create(:membership, user: organization.auto_user, organization: organization)
      end
    end
  end
end
