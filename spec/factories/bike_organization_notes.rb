FactoryBot.define do
  factory :bike_organization_note do
    bike_organization { FactoryBot.create(:bike_organization) }
    user { FactoryBot.create(:user_confirmed) }
    body { "Test note" }

    transient do
      bike { nil }
    end

    after(:build) do |note, evaluator|
      if evaluator.bike.present?
        note.bike_organization = evaluator.bike.bike_organizations.first ||
          FactoryBot.create(:bike_organization, bike: evaluator.bike)
      end
    end
  end
end
