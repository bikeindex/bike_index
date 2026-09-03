FactoryBot.define do
  factory :social_post do
    platform_id { 18.times.map { (0..9).entries.sample }.join }
    platform_response do
      JSON.parse File.read(Rails.root.join("spec", "fixtures", "integration_data_tweet.json"))
    end
  end
end
