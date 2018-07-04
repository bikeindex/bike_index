FactoryGirl.define do
  factory :bulk_import do
    sequence(:id) { |n| n } # WTF Travis? Travis is blowing up, something to do with different postgres version I'm sure
    sequence(:file_url) { |n| "https://bikeindex.org/bulk_file#{n}.csv" }
    user { FactoryGirl.create(:user) }
    factory :bulk_import_success do
      progress "finished"
    end
  end
end
