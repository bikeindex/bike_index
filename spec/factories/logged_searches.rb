# == Schema Information
#
# Table name: logged_searches
#
#  id                :bigint           not null, primary key
#  city              :string
#  duration_ms       :integer
#  endpoint          :integer
#  includes_query    :boolean          default(FALSE)
#  ip_address        :string
#  latitude          :float
#  log_line          :text
#  longitude         :float
#  neighborhood      :string
#  page              :integer
#  processed         :boolean          default(FALSE)
#  query_items       :jsonb
#  request_at        :datetime
#  serial_normalized :string
#  stolenness        :integer
#  street            :string
#  zipcode           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  country_id        :bigint
#  organization_id   :bigint
#  request_id        :uuid
#  state_id          :bigint
#  user_id           :bigint
#
# Indexes
#
#  index_logged_searches_on_country_id       (country_id)
#  index_logged_searches_on_organization_id  (organization_id)
#  index_logged_searches_on_request_id       (request_id)
#  index_logged_searches_on_state_id         (state_id)
#  index_logged_searches_on_user_id          (user_id)
#
FactoryBot.define do
  factory :logged_search do
    request_at { Time.current - 5.minutes }
    request_id { SecureRandom.uuid }
    log_line { "I, [#{request_at.utc.strftime("%FT%T%:z")} #6669]  INFO -- : [#{request_id}] {\"method\":\"GET\",\"path\":\"/bikes\",\"format\":\"html\",\"controller\":\"BikesController\",\"action\":\"index\",\"status\":200,\"duration\":1001.79,\"view\":52.68,\"db\":946.26,\"remote_ip\":\"11.222.33.4\",\"u_id\":null,\"params\":{\"non_stolen\":\"\",\"page\":\"2\",\"proximity\":\"New Orleans Louisiana\",\"proximity_radius\":\"100\",\"query\":\"\",\"stolen\":\"true\"},\"@timestamp\":\"2023-10-23T00:20:01.681Z\",\"@version\":\"1\",\"message\":\"[200] GET /bikes (BikesController#index)\"}}" }
  end
end
