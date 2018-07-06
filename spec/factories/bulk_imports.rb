FactoryGirl.define do
  factory :bulk_import do
    sequence(:id) { |n| n } # WTF Travis? Travis is blowing up, something to do with different postgres version I'm sure
    file { File.open(Rails.root.join("public", "import_only_required.csv")) }
    user { FactoryGirl.create(:user) }
    factory :bulk_import_success do
      progress "finished"
    end
  end
end
