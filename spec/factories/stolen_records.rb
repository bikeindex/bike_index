FactoryGirl.define do
  factory :stolen_record do
    bike { FactoryGirl.create(:bike) }
    date_stolen Time.now
  end
end
