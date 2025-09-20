FactoryBot.define do
  factory :logged_search do
    request_at { 5.minutes.ago }
    request_id { SecureRandom.uuid }
    log_line { "I, [#{request_at.utc.strftime("%FT%T%:z")} #6669]  INFO -- : [#{request_id}] {\"method\":\"GET\",\"path\":\"/bikes\",\"format\":\"html\",\"controller\":\"BikesController\",\"action\":\"index\",\"status\":200,\"duration\":1001.79,\"view\":52.68,\"db\":946.26,\"remote_ip\":\"11.222.33.4\",\"u_id\":null,\"params\":{\"non_stolen\":\"\",\"page\":\"2\",\"proximity\":\"New Orleans Louisiana\",\"proximity_radius\":\"100\",\"query\":\"\",\"stolen\":\"true\"},\"@timestamp\":\"2023-10-23T00:20:01.681Z\",\"@version\":\"1\",\"message\":\"[200] GET /bikes (BikesController#index)\"}}" }
  end
end
