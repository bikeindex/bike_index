FactoryBot.define do
  factory :marketplace_fee_schedule do
    platform_fee_percent { 9.0 }
    platform_fee_cap_cents { 69_00 }
    processing_fee_percent { 3.0 }
    sequence(:start_at) { |n| 1.year.ago + n.minutes }
  end
end
