FactoryGirl.define do
  factory :bulk_import do
    sequence(:file_url) { |n| "https://bikeindex.org/bulk_file#{n}.csv" }
    user { FactoryGirl.create(:user) }
    factory :bulk_import_success do
      progress "finished"
    end
  end
end
