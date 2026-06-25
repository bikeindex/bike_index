FactoryBot.define do
  factory :registration_sequence_page do
    registration_sequence
    sequence(:listing_order) { |n| n }
    body { "## Heading\n\n- point one\n- point two" }
  end
end
