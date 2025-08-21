# == Schema Information
#
# Table name: user_alerts
#
#  id              :bigint           not null, primary key
#  dismissed_at    :datetime
#  kind            :integer
#  message         :text
#  resolved_at     :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  bike_id         :bigint
#  organization_id :bigint
#  theft_alert_id  :bigint
#  user_id         :bigint
#  user_phone_id   :bigint
#
# Indexes
#
#  index_user_alerts_on_bike_id          (bike_id)
#  index_user_alerts_on_organization_id  (organization_id)
#  index_user_alerts_on_theft_alert_id   (theft_alert_id)
#  index_user_alerts_on_user_id          (user_id)
#  index_user_alerts_on_user_phone_id    (user_phone_id)
#
FactoryBot.define do
  factory :user_alert do
    user { FactoryBot.create(:user_confirmed) }
    kind { UserAlert.kinds.first }
    factory :user_alert_stolen_bike_without_location do
      kind { "stolen_bike_without_location" }
      bike do
        FactoryBot.create(:bike,
          :with_ownership_claimed,
          :with_stolen_record,
          user: user,
          latitude: nil,
          longitude: nil)
      end
    end
  end
end
