FactoryBot.define do
  factory :impound_claim do
    transient do
      organization { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "impound_bikes") }
    end
    impound_record { FactoryBot.create(:impound_record_with_organization, organization: organization) }
    user { FactoryBot.create(:user) }
    status { "pending" }

    trait :with_stolen_record do
      transient do
        bike { FactoryBot.create(:bike, :with_ownership_claimed, creator: user, user: user) }
      end
      stolen_record { FactoryBot.create(:stolen_record, bike: bike) }
    end

    factory :impound_claim_with_stolen_record, traits: [:with_stolen_record]

    trait :resolved do
      impound_record { FactoryBot.create(:impound_record_resolved, :with_organization, organization: organization, status: "retrieved_by_owner") }
      status { "retrieved" }
    end

    factory :impound_claim_resolved, traits: [:resolved]
  end
end
