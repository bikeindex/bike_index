# == Schema Information
#
# Table name: theft_alerts
#
#  id                          :integer          not null, primary key
#  ad_radius_miles             :integer
#  admin                       :boolean          default(FALSE)
#  amount_cents_facebook_spent :integer
#  end_at                      :datetime
#  facebook_data               :jsonb
#  facebook_updated_at         :datetime
#  latitude                    :float
#  longitude                   :float
#  notes                       :text
#  reach                       :integer
#  start_at                    :datetime
#  status                      :integer          default("pending"), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  bike_id                     :bigint
#  payment_id                  :integer
#  stolen_record_id            :integer
#  theft_alert_plan_id         :integer
#  user_id                     :integer
#
# Indexes
#
#  index_theft_alerts_on_bike_id              (bike_id)
#  index_theft_alerts_on_payment_id           (payment_id)
#  index_theft_alerts_on_stolen_record_id     (stolen_record_id)
#  index_theft_alerts_on_theft_alert_plan_id  (theft_alert_plan_id)
#  index_theft_alerts_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (payment_id => payments.id)
#  fk_rails_...  (stolen_record_id => stolen_records.id) ON DELETE => cascade
#  fk_rails_...  (theft_alert_plan_id => theft_alert_plans.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id)
#
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
