FactoryBot.define do
  factory :stolen_record do
    bike { FactoryBot.create(:bike) }
    date_stolen { Time.current }
    factory :stolen_record_recovered do
      date_recovered { Time.current }
      recovered_description { "Awesome help by Bike Index" }
      current { false }
    end
  end
end
