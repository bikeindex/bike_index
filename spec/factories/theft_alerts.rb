FactoryBot.define do
  factory :theft_alert do
    stolen_record { FactoryBot.create(:stolen_record) }
    theft_alert_plan { FactoryBot.create(:theft_alert_plan) }
    user { FactoryBot.create(:user_confirmed) }
    status { "pending" }
    notes { nil }

    trait :paid do
      payment { FactoryBot.create(:payment, user: user) }
    end

    trait :begun do
      status { "active" }
      start_at { Time.current }
      end_at { start_at + theft_alert_plan.duration_days.days }
    end

    trait :ended do
      status { "inactive" }
      start_at { end_at - theft_alert_plan.duration_days.days }
      end_at { Time.current }
    end

    factory :theft_alert_unpaid
    factory :theft_alert_paid, traits: [:paid]
    factory :theft_alert_begun, traits: [:paid, :begun]
    factory :theft_alert_ended, traits: [:paid, :begun, :ended]
  end
end
