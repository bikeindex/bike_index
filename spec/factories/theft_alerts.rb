FactoryBot.define do
  factory :theft_alert do
    stolen_record { create(:stolen_record) }
    theft_alert_plan { create(:theft_alert_plan) }
    creator { create(:user_confirmed) }
    status { "pending" }

    trait :paid do
      after(:create) do |theft_alert, _evaluator|
        payment = create(:payment, user: theft_alert.creator)
        theft_alert.update_attributes(payment: payment)
      end
    end

    trait :begun do
      status { "active" }
      begin_at { Time.current.beginning_of_day }
      sequence(:facebook_post_url) do |n|
        "https://facebook.com/user.#{creator.id}/posts/#{n}"
      end
      before(:create) do |theft_alert, _evaluator|
        plan = create(:theft_alert_plan)

        duration = plan.duration_days
        end_at = theft_alert.begin_at + duration.days

        theft_alert.theft_alert_plan = plan
        theft_alert.end_at = end_at.end_of_day

        theft_alert.save
      end
    end

    trait :ended do
      status { "inactive" }
      end_at { Time.current.end_of_day }

      before(:create) do |theft_alert, _evaluator|
        plan = create(:theft_alert_plan)

        duration = plan.duration_days
        begin_at = theft_alert.end_at - duration.days

        theft_alert.theft_alert_plan = plan
        theft_alert.begin_at = begin_at.beginning_of_day

        theft_alert.save
      end
    end

    factory :theft_alert_pending
    factory :theft_alert_paid, traits: [:paid]
    factory :theft_alert_begun, traits: [:paid, :begun]
    factory :theft_alert_ended, traits: [:paid, :begun, :ended]
  end
end
