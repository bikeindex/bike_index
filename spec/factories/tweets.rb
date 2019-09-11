FactoryBot.define do
  factory :tweet do
    twitter_id { 18.times.map { (0..9).entries.sample }.join }
    twitter_response { File.read(Rails.root.join("spec", "fixtures", "integration_data_tweet.json")) }
  end
end
