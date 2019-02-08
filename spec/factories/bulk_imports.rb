FactoryBot.define do
  factory :bulk_import do
    sequence(:id) { |n| n } # WTF Travis? Travis is blowing up, something to do with different postgres version I'm sure
    file { File.open(Rails.root.join("public", "import_only_required.csv")) }
    user { FactoryBot.create(:user) }
    factory :bulk_import_ascend do
      file { File.open(Rails.root.join("public", "Bike_Index_Reserve_20190207_-_BIKE_LANE_CHIC.csv")) }
      is_ascend { true }
      organization { nil }
      user { nil }
    end
    factory :bulk_import_success do
      progress { "finished" }
    end
  end
end
