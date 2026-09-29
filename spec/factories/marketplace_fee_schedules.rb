FactoryBot.define do
  factory :marketplace_fee_schedule do
    platform_fee_percent { 9.0 }
    platform_fee_cap_cents { 69_00 }
    processing_fee_percent { 3.0 }
    sequence(:start_at) { |n| 1.day.from_now + n.minutes }

    # A schedule can't be created to start in the past, so a started one skips validation to be inserted with its past start_at
    trait :started do
      sequence(:start_at) { |n| 1.year.ago + n.minutes }
      to_create { |schedule| schedule.save!(validate: false) }
    end
  end
end
