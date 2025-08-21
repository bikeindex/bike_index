# == Schema Information
#
# Table name: users
#
#  id                                 :integer          not null, primary key
#  address_set_manually               :boolean          default(FALSE)
#  admin_options                      :jsonb
#  alert_slugs                        :jsonb
#  auth_token                         :string(255)
#  avatar                             :string(255)
#  banned                             :boolean          default(FALSE), not null
#  can_send_many_stolen_notifications :boolean          default(FALSE), not null
#  city                               :string
#  confirmation_token                 :string(255)
#  confirmed                          :boolean          default(FALSE), not null
#  deleted_at                         :datetime
#  description                        :text
#  developer                          :boolean          default(FALSE), not null
#  email                              :string(255)
#  instagram                          :string
#  last_login_at                      :datetime
#  last_login_ip                      :string
#  latitude                           :float
#  longitude                          :float
#  magic_link_token                   :text
#  my_bikes_hash                      :jsonb
#  name                               :string(255)
#  neighborhood                       :string
#  no_address                         :boolean          default(FALSE)
#  no_non_theft_notification          :boolean          default(FALSE)
#  notification_newsletters           :boolean          default(FALSE), not null
#  notification_unstolen              :boolean          default(TRUE)
#  partner_data                       :jsonb
#  password                           :text
#  password_digest                    :string(255)
#  phone                              :string(255)
#  preferred_language                 :string
#  show_bikes                         :boolean          default(FALSE), not null
#  show_instagram                     :boolean          default(FALSE)
#  show_phone                         :boolean          default(TRUE)
#  show_twitter                       :boolean          default(FALSE), not null
#  show_website                       :boolean          default(FALSE), not null
#  street                             :string
#  superuser                          :boolean          default(FALSE), not null
#  terms_of_service                   :boolean          default(FALSE), not null
#  time_single_format                 :boolean          default(FALSE)
#  title                              :text
#  token_for_password_reset           :text
#  twitter                            :string(255)
#  username                           :string(255)
#  vendor_terms_of_service            :boolean
#  when_vendor_terms_of_service       :datetime
#  zipcode                            :string(255)
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  address_record_id                  :bigint
#  country_id                         :integer
#  state_id                           :integer
#  stripe_id                          :string(255)
#
# Indexes
#
#  index_users_on_address_record_id         (address_record_id)
#  index_users_on_auth_token                (auth_token)
#  index_users_on_token_for_password_reset  (token_for_password_reset)
#
FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n.to_s.rjust(4, "0")}" }
    email { generate(:unique_email) }
    password { "testthisthing7$" }
    password_confirmation { "testthisthing7$" }
    terms_of_service { true }

    # Set latitude and longitude from address_record if it's present
    latitude { address_record&.latitude }
    longitude { address_record&.longitude }

    trait :confirmed do
      after(:create) { |u| u.confirm(u.confirmation_token) }
    end

    trait :with_address_record do
      address_record { FactoryBot.build(:address_record, kind: :user) }

      after(:create) do |user, _evaluator|
        user.address_record.update(user_id: user.id)
      end
    end

    factory :user_confirmed, traits: [:confirmed] do
      factory :user_bikehub_signup do
        partner_data { {sign_up: "bikehub"} }
      end
      factory :superuser do
        accepted_vendor_terms_of_service { true }
        superuser { true }
        factory :superuser_developer do
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
        FactoryBot.create(:organization_role_claimed, user: user,
          organization: evaluator.organization,
          role: evaluator.role)
      end
    end

    factory :organization_user, traits: [:with_organization]

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
