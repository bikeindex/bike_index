FactoryBot.define do
  factory :user do
    name
    email { generate(:unique_email) }
    password { 'testthisthing7$' }
    password_confirmation { 'testthisthing7$' }
    terms_of_service { true }
    factory :user_confirmed do
      after(:create) { |u| u.confirm(u.confirmation_token) }
      factory :user_bikehub_signup do
        partner_data { { sign_up: "bikehub" } }
      end
      factory :admin do
        superuser { true }
        factory :admin_developer do
          developer { true }
        end
      end
      factory :developer do
        developer { true }
      end
      factory :organized_user do
        # This factory should not be used directly, it's here to wrap organization
        # Use `organization_member` or `organization_admin`
        transient do
          organization { FactoryBot.create(:organization) }
        end
        factory :organization_member do
          after(:create) do |user, evaluator|
            FactoryBot.create(:membership, user: user, organization: evaluator.organization)
          end
        end
        factory :organization_auto_user do
          after(:create) do |user, evaluator|
            FactoryBot.create(:membership, user: user, organization: evaluator.organization)
            evaluator.organization.update_attribute :auto_user_id, user.id
          end
        end
        factory :organization_admin do
          after(:create) do |user, evaluator|
            FactoryBot.create(:membership, user: user, organization: evaluator.organization, role: 'admin')
          end
        end
      end
    end
  end
end
