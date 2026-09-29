FactoryBot.define do
  factory :marketplace_fee_schedule do
    platform_fee_percent { 9.0 }
    platform_fee_cap_cents { 69_00 }
    processing_fee_percent { 3.0 }
    sequence(:start_at) { |n| 1.day.from_now + n.minutes }

    # A schedule can't be created to start in the past, so a started one is moved back once it's saved
    trait :started do
      transient { sequence(:started_at) { |n| 1.year.ago + n.minutes } }
      after(:create) { |schedule, evaluator| schedule.update_columns(start_at: evaluator.started_at) }
    end
  end
end
