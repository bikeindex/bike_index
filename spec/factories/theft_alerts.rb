FactoryBot.define do
  factory :promoted_alert do
    stolen_record { FactoryBot.create(:stolen_record) }
    promoted_alert_plan { FactoryBot.create(:promoted_alert_plan) }
    user { FactoryBot.create(:user_confirmed) }
    status { "pending" }
    notes { nil }

    trait :paid do
      payment { FactoryBot.create(:payment, user: user) }
    end

    trait :begun do
      status { "active" }
      start_at { Time.current }
      end_at { start_at + promoted_alert_plan.duration_days.days }
    end

    trait :ended do
      status { "inactive" }
      start_at { end_at - promoted_alert_plan.duration_days.days }
      end_at { Time.current }
    end

    factory :promoted_alert_unpaid
    factory :promoted_alert_paid, traits: [:paid]
    factory :promoted_alert_begun, traits: [:paid, :begun]
    factory :promoted_alert_ended, traits: [:paid, :begun, :ended]
  end
end
