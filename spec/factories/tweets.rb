# == Schema Information
#
# Table name: tweets
#
#  id                 :integer          not null, primary key
#  alignment          :string
#  body               :text
#  body_html          :text
#  image              :string
#  kind               :integer
#  twitter_response   :json
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  original_tweet_id  :integer
#  stolen_record_id   :integer
#  twitter_account_id :integer
#  twitter_id         :string
#
# Indexes
#
#  index_tweets_on_original_tweet_id   (original_tweet_id)
#  index_tweets_on_stolen_record_id    (stolen_record_id)
#  index_tweets_on_twitter_account_id  (twitter_account_id)
#
FactoryBot.define do
  factory :tweet do
    twitter_id { 18.times.map { (0..9).entries.sample }.join }
    twitter_response do
      JSON.parse File.read(Rails.root.join("spec", "fixtures", "integration_data_tweet.json"))
    end
  end
end
