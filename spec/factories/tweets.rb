FactoryGirl.define do
  factory :tweet do
    twitter_id '874644243737751553'
    twitter_response File.read(Rails.root.join('spec', 'fixtures', 'integration_data_tweet.json'))
  end
end
