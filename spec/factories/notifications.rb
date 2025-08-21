# == Schema Information
#
# Table name: notifications
#
#  id                     :bigint           not null, primary key
#  delivery_error         :string
#  delivery_status        :integer
#  kind                   :integer
#  message_channel        :integer          default("email")
#  message_channel_target :string
#  notifiable_type        :string
#  twilio_sid             :text
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  bike_id                :bigint
#  message_id             :string
#  notifiable_id          :bigint
#  user_id                :bigint
#
# Indexes
#
#  index_notifications_on_bike_id                            (bike_id)
#  index_notifications_on_notifiable_type_and_notifiable_id  (notifiable_type,notifiable_id)
#  index_notifications_on_user_id                            (user_id)
#
FactoryBot.define do
  factory :notification do
    user { FactoryBot.create(:user) }
    kind { :confirmation_email }
  end
end
