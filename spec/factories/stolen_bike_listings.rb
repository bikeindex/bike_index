FactoryBot.define do
  factory :stolen_bike_listing do
    manufacturer { FactoryBot.create(:manufacturer) }
    primary_frame_color { Color.black }
  end
end
