FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n.to_s.rjust(3, "0")}" }
    short_name { name }
    available_invitation_count { 5 }
    show_on_map { false }
    lock_show_on_map { false }
    api_access_approved { false }
    sequence(:website) { |n| "http://organization#{n}.com" }

    factory :organization_with_paid_features do
      transient do
        paid_feature_slugs { ["csv_export"] }
        paid_feature { FactoryBot.create(:paid_feature, amount_cents: 10_000, feature_slugs: Array(paid_feature_slugs)) }
        after(:create) do |organization, evaluator|
          invoice = FactoryBot.create(:invoice_paid, amount_due: 0, organization: organization)
          invoice.update_attributes(paid_feature_ids: [evaluator.paid_feature.id])
          organization.update_attributes(updated_at: Time.current) # TODO: Rails 5 update - after commit doesn't run
        end
      end
    end

    # before(:create) { |organization| organization.short_name ||= organization.name }
    factory :organization_with_auto_user do
      auto_user { FactoryBot.create(:user) }
      after(:create) do |organization|
        FactoryBot.create(:membership_claimed, user: organization.auto_user, organization: organization)
      end
    end
    factory :organization_child do
      parent_organization { FactoryBot.create(:organization) }
    end

    factory :organization_ambassador do
      kind { "ambassador" }
      sequence(:name) { |n| "Ambassador Group #{n.to_s.rjust(3, "0")}" }
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
