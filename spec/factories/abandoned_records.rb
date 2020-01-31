FactoryBot.define do
  factory :abandoned_record do
    bike { FactoryBot.create(:bike) }
    user { FactoryBot.create(:user) }

    latitude { 40.7143528 }
    longitude { -74.0059731 }
    # address { "278 Broadway, New York, NY 10007, USA" }

    trait :in_los_angeles do
      latitude { 34.05223 }
      longitude { -118.24368 }
      city { "Los Angeles" }
      state { State.find_or_create_by(FactoryBot.attributes_for(:state_california)) }
      country { Country.united_states }
    end

    factory :abandoned_record_organized do
      user { FactoryBot.create(:organization_member, organization: organization) }
      organization { FactoryBot.create(:organization_with_paid_features, paid_feature_slugs: "impound_bikes") }
    end
  end
end
