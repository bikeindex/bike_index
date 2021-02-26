FactoryBot.define do
  factory :theft_ring_listing do
    manufacturer { FactoryBot.create(:manufacturer) }
    primary_frame_color { Color.black }
  end
end
