FactoryGirl.define do
  factory :bulk_import do
    sequence(:file_url) { |n| "https://bikeindex.org/bulk_file#{n}.csv" }
    organization { FactoryGirl.create(:organization) }
    bikes_imported 2
  end
end
