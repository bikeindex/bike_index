require 'spec_helper'

RSpec.describe Tweet, type: :model do
  let(:twitter_response) { File.read(Rails.root.join('spec', 'fixtures', 'integration_data_tweet.json')) }

  describe 'validations' do
    it { should validate_presence_of :twitter_id }
  end

  describe 'friendly_find' do
    let!(:tweet) { FactoryGirl.create(:tweet) }
    let(:twitter_id) { tweet.twitter_id }
    context 'twitter_id' do
      it 'finds the tweet' do
        expect(Tweet.friendly_find(twitter_id)).to eq tweet
      end
    end
    context 'our id' do
      it 'finds the tweet' do
        expect(Tweet.friendly_find(tweet.id)).to eq tweet
      end
    end
    context 'not found' do
      it 'does not error' do
        expect(Tweet.friendly_find(1111111)).to be_nil
      end
    end
  end

  describe 'ensure_valid_alignment' do
    it 'adds an error if alignment invalid' do
      expect(Tweet.new(twitter_id: 111, alignment: 'weird').valid?).to be_falsey
    end
  end

  describe 'auto_link_mentions' do
    it 'auto links mentioned folk' do
      input = 'Portland Patrol officer Baxter assists in another #biketheft recovery today in Old Town! Great looking out and using @stolenbikereg 👍'
      target = 'Portland Patrol officer Baxter assists in another <a href="https://twitter.com/hashtag/biketheft" target="_blank">#biketheft</a> recovery today in Old Town! Great looking out and using <a href="https://twitter.com/stolenbikereg" target="_blank">@stolenbikereg</a> 👍'
      expect(Tweet.auto_link_text(input)).to eq target
    end
  end

  context 'twitter response present' do
    let(:tweet) { Tweet.new(twitter_id: '874644243737751553', twitter_response: twitter_response) }
    it 'sets the body on create' do
      tweet.save
      expect(tweet.body_html).to eq 'Remember this stolen Novara? The "Wedding gift" bike? It has now been recovered with an assist by <a href="https://twitter.com/PPBBikeTheft" target="_blank">@PPBBikeTheft</a> :) https://t.co/hiZZYtCBC1'
    end

    it 'gives us the responses we want' do
      expect(tweet.tweetor).to eq 'stolenbikereg'
      expect(tweet.tweeted_at.to_i).to eq 1497366412
      expect(tweet.tweetor_avatar).to eq 'https://pbs.twimg.com/profile_images/505773652646711296/bTYbvFTy_normal.jpeg'
      expect(tweet.tweetor_name).to eq 'BikeIndex Portland'
    end
  end
end
