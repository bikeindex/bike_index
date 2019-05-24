FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    short_name { name }
    available_invitation_count { 5 }
    show_on_map { false }
    lock_show_on_map { false }
    api_access_approved { false }
    sequence(:website) { |n| "http://organization#{n}.com" }

    # before(:create) { |organization| organization.short_name ||= organization.name }
    factory :organization_with_auto_user do
      auto_user { FactoryBot.create(:user) }
      after(:create) do |organization|
        FactoryBot.create(:membership, user: organization.auto_user, organization: organization)
      end
    end
    factory :organization_child do
      parent_organization { FactoryBot.create(:organization) }
    end

    factory :organization_ambassador do
      kind { "ambassador" }
      sequence(:name) { |n| "Ambassador Group #{n}" }
    end

    trait :with_locations do
      after(:create) do |organization|
        2.times do |n|
          FactoryBot.create(:location,
                            name: "location #{n}",
                            organization: organization)
        end
      end
    end
  end
end
