FactoryGirl.define do
  factory :bulk_import do
    sequence(:file_url) { |n| "https://bikeindex.org/bulk_file#{n}.csv" }
    user { FactoryGirl.create(:user) }
    organization { FactoryGirl.create(:organization) }
    factory :bulk_import_success do
      bikes_imported 2
    end
  end
end
