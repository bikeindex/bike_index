FactoryBot.define do
  factory :theft_alert do
    stolen_record { create(:stolen_record) }
    theft_alert_plan { create(:theft_alert_plan) }
    creator { create(:user_confirmed) }
    status { "pending" }

    trait :paid do
      transient do
        payment { create(:payment, user: creator) }
      end
      after(:create) do |theft_alert, evaluator|
        theft_alert.update_attributes(payment: evaluator.payment)
      end
    end

    trait :begun do
      status { "active" }
      begin_at { Time.current.beginning_of_day }
      sequence(:facebook_post_url) do |n|
        "https://facebook.com/user.#{creator.id}/posts/#{n}"
      end
      transient do
        theft_alert_plan { create(:theft_alert_plan) }
      end
      before(:create) do |theft_alert, evaluator|
        plan = evaluator.theft_alert_plan
        theft_alert.theft_alert_plan = plan
        theft_alert.end_at = theft_alert.begin_at + plan.duration_days.days
        theft_alert.save
      end
    end

    trait :ended do
      status { "inactive" }
      end_at { Time.current }

      transient do
        theft_alert_plan { create(:theft_alert_plan) }
      end

      before(:create) do |theft_alert, evaluator|
        plan = evaluator.theft_alert_plan
        theft_alert.theft_alert_plan = plan
        theft_alert.begin_at = theft_alert.end_at - plan.duration_days.days
        theft_alert.save
      end
    end

    factory :theft_alert_pending
    factory :theft_alert_paid, traits: [:paid]
    factory :theft_alert_begun, traits: [:paid, :begun]
    factory :theft_alert_ended, traits: [:paid, :begun, :ended]
  end
end
