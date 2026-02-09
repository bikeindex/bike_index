FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n.to_s.rjust(3, "0")}" }
    short_name { name }
    available_invitation_count { 5 }
    show_on_map { false }
    lock_show_on_map { false }
    api_access_approved { false }
    sequence(:website) { |n| "http://organization#{n}.com" }

    trait :in_nyc do
      after(:create) do |org|
        FactoryBot.create(:location, :with_address_record, address_in: :new_york, organization: org)
      end
    end

    trait :in_chicago do
      after(:create) do |org|
        FactoryBot.create(:location, :with_address_record, address_in: :chicago, organization: org)
      end
    end

    trait :in_los_angeles do
      after(:create) do |org|
        FactoryBot.create(:location, :with_address_record, address_in: :los_angeles, organization: org)
      end
    end

    trait :in_edmonton do
      after(:create) do |org|
        FactoryBot.create(:location, :with_address_record, address_in: :edmonton, organization: org)
      end
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

    trait :paid do
      transient do
        enabled_feature_slugs { nil }
        organization_feature { nil }
      end

      after(:create) do |organization, evaluator|
        Sidekiq::Testing.inline! do
          invoice = FactoryBot.create(:invoice_paid, amount_due: 0, organization: organization)
          invoice.update(organization_feature_ids: [evaluator.organization_feature&.id])
          organization.reload
        end
      end
    end

    # TODO: Figure out how to use the :paid trait rather than duplicating the logic
    trait :organization_features do
      transient do
        enabled_feature_slugs { ["csv_export"] }
        organization_feature { FactoryBot.create(:organization_feature, amount_cents: 10_000, feature_slugs: Array(enabled_feature_slugs)) }
      end

      after(:create) do |organization, evaluator|
        Sidekiq::Testing.inline! do
          invoice = FactoryBot.create(:invoice_paid, amount_due: 0, organization: organization)
          invoice.update(organization_feature_ids: [evaluator.organization_feature&.id])
          organization.reload
        end
      end
    end

    factory :organization_with_organization_features, traits: [:organization_features] do
      factory :organization_with_regional_bike_counts do
        enabled_feature_slugs { ["regional_bike_counts"] }
      end
    end

    trait :with_auto_user do
      # passing in user DOESN'T ACTUALLY WORK!! TODO: make it work
      transient { user { FactoryBot.create(:user_confirmed) } }

      after(:create) do |organization, evaluator|
        FactoryBot.create(:organization_role_claimed, user: evaluator.user, organization: organization)
        organization.update(auto_user: evaluator.user)
      end
    end

    factory :organization_with_auto_user, traits: [:with_auto_user]

    factory :organization_child do
      parent_organization { FactoryBot.create(:organization) }
    end

    factory :organization_ambassador do
      kind { "ambassador" }
      sequence(:name) { |n| "Ambassador Group #{n.to_s.rjust(3, "0")}" }
    end
  end
end
