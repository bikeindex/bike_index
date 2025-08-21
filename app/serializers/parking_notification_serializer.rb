# == Schema Information
#
# Table name: parking_notifications
#
#  id                    :integer          not null, primary key
#  accuracy              :float
#  city                  :string
#  delivery_status       :string
#  hide_address          :boolean          default(FALSE)
#  image                 :text
#  image_processing      :boolean          default(FALSE), not null
#  internal_notes        :text
#  kind                  :integer          default("appears_abandoned_notification")
#  latitude              :float
#  location_from_address :boolean          default(FALSE)
#  longitude             :float
#  message               :text
#  neighborhood          :string
#  repeat_number         :integer
#  resolved_at           :datetime
#  retrieval_link_token  :text
#  retrieved_kind        :integer
#  status                :integer          default("current")
#  street                :string
#  unregistered_bike     :boolean          default(FALSE)
#  zipcode               :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  bike_id               :integer
#  country_id            :bigint
#  impound_record_id     :integer
#  initial_record_id     :integer
#  organization_id       :integer
#  retrieved_by_id       :bigint
#  state_id              :bigint
#  user_id               :integer
#
# Indexes
#
#  index_parking_notifications_on_bike_id            (bike_id)
#  index_parking_notifications_on_country_id         (country_id)
#  index_parking_notifications_on_impound_record_id  (impound_record_id)
#  index_parking_notifications_on_initial_record_id  (initial_record_id)
#  index_parking_notifications_on_organization_id    (organization_id)
#  index_parking_notifications_on_retrieved_by_id    (retrieved_by_id)
#  index_parking_notifications_on_state_id           (state_id)
#  index_parking_notifications_on_user_id            (user_id)
#
class ParkingNotificationSerializer < ApplicationSerializer
  attributes :id,
    :kind,
    :kind_humanized,
    :status,
    :created_at,
    :lat,
    :lng,
    :user_id,
    :user_display_name,
    :bike,
    :notification_number,
    :impound_record_id,
    :unregistered_bike,
    :message,
    :internal_notes,
    :image_url,
    :resolved_at

  def perform_caching
    true
  end

  def created_at
    object.created_at.to_i
  end

  def user_id
    object.user_id
  end

  def user_display_name
    object.user&.display_name
  end

  def lat
    object.latitude
  end

  def lng
    object.longitude
  end

  def resolved_at
    object.resolved_at&.to_i
  end

  def impound_record_id
    object.impound_record_id
  end

  def bike
    bike_obj = object.bike
    {
      id: bike_obj&.id,
      title: bike_obj&.title_string
    }
  end
end
