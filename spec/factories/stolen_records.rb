FactoryBot.define do
  factory :stolen_record do
    bike { FactoryBot.create(:bike, :with_image) }
    date_stolen { Time.current }
    sequence(:alert_image) { |i| File.open(ApplicationUploader.cache_dir.join("alert_image#{i}-alert.jpg"), "w+") }

    factory :stolen_record_recovered do
      date_recovered { Time.current }
      recovered_description { "Awesome help by Bike Index" }
      current { false }
    end

    trait :no_bike_image do
      bike { FactoryBot.create(:bike) }
    end
  end
end
