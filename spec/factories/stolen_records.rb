FactoryBot.define do
  factory :stolen_record do
    bike { FactoryBot.create(:bike, :with_image) }
    date_stolen { Time.current }
    alert_image { nil }

    factory :stolen_record_recovered do
      bike { FactoryBot.create(:bike, :with_image) }
      date_recovered { Time.current }
      recovered_description { "Awesome help by Bike Index" }
      current { false }
    end

    trait :with_alert_image do
      transient do
        filename { nil }
      end

      after(:create) do |stolen_record, evaluator|
        filename = evaluator.filename || "stolen_record-#{stolen_record.id}.jpg"
        stolen_record.alert_image = File.open(ApplicationUploader.cache_dir.join(filename), "w+")
        stolen_record.save
      end
    end

    trait :no_bike_image do
      bike { FactoryBot.create(:bike) }
    end
  end
end
