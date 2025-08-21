# == Schema Information
#
# Table name: stolen_notifications
#
#  id                   :integer          not null, primary key
#  kind                 :integer
#  message              :text
#  receiver_email       :string(255)
#  reference_url        :text
#  send_dates           :json
#  subject              :string(255)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  bike_id              :integer
#  doorkeeper_app_id    :bigint
#  oauth_application_id :integer
#  receiver_id          :integer
#  sender_id            :integer
#
# Indexes
#
#  index_stolen_notifications_on_doorkeeper_app_id     (doorkeeper_app_id)
#  index_stolen_notifications_on_oauth_application_id  (oauth_application_id)
#
class StolenNotificationSerializer < ApplicationSerializer
  attributes :message
end
