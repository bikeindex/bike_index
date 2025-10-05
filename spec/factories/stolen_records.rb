FactoryBot.define do
  factory :stolen_record do
    bike { FactoryBot.create(:bike) }
    date_stolen { Time.current }
    skip_geocoding { true }

    factory :stolen_record_recovered do
      bike { FactoryBot.create(:bike) }
      recovered_at { Time.current }
      recovered_description { "Awesome help by Bike Index" }
      current { false }
    end

    trait :with_images do
      transient do
        filename { Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg") }
      end
      # NOTE: Only attaches 2 photos, because those are the only ones used currently
      after(:build) do |stolen_record, evaluator|
        stolen_record.image_four_by_five.attach(io: File.open(evaluator.filename),
          filename: "stolen-#{stolen_record.id}-four_by_five.jpeg")
        stolen_record.image_opengraph.attach(io: File.open(evaluator.filename),
          filename: "stolen-#{stolen_record.id}-opengraph.jpeg")
      end
    end

    trait :with_alert_image do
      transient do
        filename { nil }
      end

      after(:create) do |stolen_record, evaluator|
        FactoryBot.create(:alert_image,
          :with_image,
          stolen_record: stolen_record,
          filename: evaluator.filename)
      end
    end

    trait :with_bike_image do
      bike { FactoryBot.create(:bike, :with_image) }
    end
  end
end
