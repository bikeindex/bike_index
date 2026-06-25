FactoryBot.define do
  factory :registration_sequence_page do
    registration_sequence
    sequence(:listing_order) { |n| n }
    content { "<ul><li>point one</li><li>point two</li></ul>" }
  end
end
