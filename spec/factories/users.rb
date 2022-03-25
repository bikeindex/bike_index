FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n.to_s.rjust(4, "0")}" }
    email { generate(:unique_email) }
    password { "testthisthing7$" }
    password_confirmation { "testthisthing7$" }
    terms_of_service { true }

    trait :confirmed do
      after(:create) { |u| u.confirm(u.confirmation_token) }
    end

    factory :user_confirmed, traits: [:confirmed] do
      factory :user_bikehub_signup do
        partner_data { {sign_up: "bikehub"} }
      end
      factory :admin do
        accepted_vendor_terms_of_service { true }
        superuser { true }
        factory :admin_developer do
          developer { true }
        end
      end
      factory :developer do
        developer { true }
      end
    end

    trait :with_organization do
      confirmed

      transient do
        role { "member" }
        organization { FactoryBot.create(:organization) }
      end

      accepted_vendor_terms_of_service { true } # Necessary so everyone doesn't redirect back accept_vendor_terms

      after(:create) do |user, evaluator|
        FactoryBot.create(:membership_claimed, user: user,
          organization: evaluator.organization,
          role: evaluator.role)
      end
    end

    factory :organization_member, traits: [:with_organization]

    factory :organization_auto_user, traits: [:with_organization] do
      after(:create) do |user, evaluator|
        evaluator.organization.update_attribute :auto_user_id, user.id
      end
    end

    factory :organization_admin, traits: [:with_organization] do
      role { "admin" }
    end

    factory :ambassador, class: Ambassador, traits: [:with_organization] do
      transient do
        organization { FactoryBot.create(:organization_ambassador) }
      end
    end
  end
end
