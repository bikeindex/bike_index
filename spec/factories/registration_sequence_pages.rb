FactoryBot.define do
  factory :registration_sequence_page do
    registration_sequence
    sequence(:listing_order) { |n| n }
    bullet_points { ["point one", "point two"] }
  end
end
