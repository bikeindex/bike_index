FactoryBot.define do
  factory :impound_record do
    bike { FactoryBot.create(:bike, created_at: created_at) }
    user { FactoryBot.create(:user) }

    trait :with_organization do
      organization { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "impound_bikes") }
      user { FactoryBot.create(:organization_user, organization: organization) }
    end

    trait :with_address_record do
      transient do
        address_in { :chicago }
      end

      address_record do
        FactoryBot.build(:address_record, address_in, kind: :impounded_from, organization: instance.organization)
      end
    end

    factory :impound_record_with_organization, traits: [:with_organization]

    # Bump the bike to make impound_record the current_impound_record, if it should be
    after(:create) do |impound_record, _evaluator|
      impound_record.bike&.update(updated_at: Time.current)
    end

    factory :impound_record_resolved do
      status { "retrieved_by_owner" }
      after(:create) do |impound_record, evaluator|
        FactoryBot.create(:impound_record_update,
          impound_record: impound_record,
          kind: evaluator.status)

        impound_record.bike&.update(updated_at: Time.current)
      end
    end
  end
end
