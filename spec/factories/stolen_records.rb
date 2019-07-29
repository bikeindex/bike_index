FactoryBot.define do
  factory :stolen_record do
    bike { FactoryBot.create(:bike, :with_image) }
    date_stolen { Time.current }
    alert_image { File.open(Rails.root.join("spec", "fixtures", "bike.jpg")) }

    factory :stolen_record_recovered do
      date_recovered { Time.current }
      recovered_description { "Awesome help by Bike Index" }
      current { false }
    end

    trait :no_photo do
      bike { FactoryBot.create(:bike) }
    end
  end
end
