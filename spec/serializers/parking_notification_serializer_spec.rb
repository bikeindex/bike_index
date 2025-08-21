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
require "rails_helper"

RSpec.describe ParkingNotificationSerializer, type: :lib do
  let(:subject) { described_class }
  let(:obj) { FactoryBot.create(:parking_notification) }
  let(:serializer) { subject.new(obj, root: false) }

  it "works" do
    expect(serializer.as_json.is_a?(Hash)).to be_truthy
  end
  describe "caching" do
    include_context :caching_basic
    it "is cached" do
      expect(serializer.perform_caching).to be_truthy
    end
  end
end
