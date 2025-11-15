require "rails_helper"

RSpec.describe Tweet, type: :model do
  let(:platform_response) do
    JSON.parse File.read Rails.root.join("spec", "fixtures", "integration_data_tweet.json")
  end

  describe "friendly_find" do
    let!(:social_post) { FactoryBot.create(:social_post) }
    let(:platform_id) { tweet.platform_id }
    context "platform_id" do
      it "finds the tweet" do
        expect(Tweet.friendly_find(platform_id)).to eq tweet
      end
    end
    context "our id" do
      it "finds the tweet" do
        expect(Tweet.friendly_find(tweet.id)).to eq tweet
      end
    end
    context "not found" do
      it "does not error" do
        expect(Tweet.friendly_find(1111111)).to be_nil
      end
    end
  end

  describe "admin_search" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let(:platform_id) { "067802552792796306" }
    let!(:social_post) { FactoryBot.create(:social_post, stolen_record_id: bike.current_stolen_record.id, platform_id: platform_id) }
    it "finds the tweet" do
      expect(tweet.kind).to eq "stolen_tweet"
      expect(Tweet.admin_search("@PPBBIKETHEF").pluck(:id)).to eq([tweet.id])
      # This matches the tweet body - but if passed a number, admin_search only matches the actual bike id
      expect(Tweet.admin_search("119680 ").pluck(:id)).to eq([])
      expect(Tweet.admin_search(" #{bike.id}").pluck(:id)).to eq([tweet.id])
      expect(Tweet.admin_search("something else").pluck(:id)).to eq([])
      # Ensure passing a tweet id finds the tweet, and passing most of a tweet id finds the tweet too!
      expect(Tweet.admin_search(platform_id).pluck(:id)).to eq([tweet.id])
      expect(Tweet.admin_search(platform_id.slice(0, platform_id.length - 1)).pluck(:id)).to eq([tweet.id])
    end
  end

  describe "#repost?" do
    context "given no original tweet" do
      it "returns false" do
        tweet = FactoryBot.create(:social_post, original_tweet: nil)
        expect(tweet).to_not be_repost
      end
    end

    context "given an original tweet" do
      it "returns true" do
        tweet = FactoryBot.create(:social_post, original_tweet: nil)
        repost = FactoryBot.create(:social_post, original_tweet: tweet)
        expect(tweet).to_not be_repost
        expect(repost).to be_repost
      end
    end
  end

  describe "ensure_valid_alignment" do
    it "adds an error if alignment invalid" do
      expect(Tweet.new(platform_id: 111, alignment: "weird").valid?).to be_falsey
    end
  end

  describe "auto_link_mentions" do
    it "auto links mentioned folk" do
      input = "Portland Patrol officer Baxter assists in another #biketheft recovery today in Old Town! Great looking out and using @stolenbikereg 👍"
      target = 'Portland Patrol officer Baxter assists in another <a href="https://twitter.com/hashtag/biketheft" target="_blank">#biketheft</a> recovery today in Old Town! Great looking out and using <a href="https://twitter.com/stolenbikereg" target="_blank">@stolenbikereg</a> 👍'
      expect(Tweet.auto_link_text(input)).to eq target
    end
  end

  context "twitter response present" do
    let(:social_post) { Tweet.new(platform_id: "874644243737751553", platform_response: platform_response) }
    it "sets the body on create" do
      tweet.save
      expect(tweet.body_html).to eq 'Remember this stolen Novara? The "Wedding gift" bike? It has now been recovered with an assist by <a href="https://twitter.com/PPBBikeTheft" target="_blank">@PPBBikeTheft</a> :) https://t.co/hiZZYtCBC1'
    end

    it "gives us the responses we want" do
      expect(tweet.postor).to eq "stolenbikereg"
      expect(tweet.posted_at.to_i).to eq 1497366412
      expect(tweet.postor_avatar).to eq "https://pbs.twimg.com/profile_images/505773652646711296/bTYbvFTy_normal.jpeg"
      expect(tweet.postor_name).to eq "BikeIndex Portland"
      expect(tweet.posted_image).to be_blank
    end

    describe "twitter response access" do
      let(:platform_response) { '{"created_at":"Tue Sep 01 05:59:55 +0000 2020","id":1300674730798661633,"id_str":"1300674730798661633","text":"STOLEN - Black Cannondale Bad Boy in Richfield, MN https://t.co/HskxBZRGv3 https://t.co/h0ULGHBF0Y","truncated":false,"entities":{"hashtags":[],"symbols":[],"user_mentions":[],"urls":[{"url":"https://t.co/HskxBZRGv3","expanded_url":"https://bikeindex.org/bikes/849746","display_url":"bikeindex.org/bikes/849746","indices":[51,74]}],"media":[{"id":1300674729456484352,"id_str":"1300674729456484352","indices":[75,98],"media_url":"http://pbs.twimg.com/media/EgzsxnGUwAA_SNx.jpg","media_url_https":"https://pbs.twimg.com/media/EgzsxnGUwAA_SNx.jpg","url":"https://t.co/h0ULGHBF0Y","display_url":"pic.twitter.com/h0ULGHBF0Y","expanded_url":"https://twitter.com/bikeindexstolen/status/1300674730798661633/photo/1","type":"photo","sizes":{"thumb":{"w":150,"h":150,"resize":"crop"},"large":{"w":1200,"h":713,"resize":"fit"},"small":{"w":680,"h":404,"resize":"fit"},"medium":{"w":1200,"h":713,"resize":"fit"}}}]},"extended_entities":{"media":[{"id":1300674729456484352,"id_str":"1300674729456484352","indices":[75,98],"media_url":"http://pbs.twimg.com/media/EgzsxnGUwAA_SNx.jpg","media_url_https":"https://pbs.twimg.com/media/EgzsxnGUwAA_SNx.jpg","url":"https://t.co/h0ULGHBF0Y","display_url":"pic.twitter.com/h0ULGHBF0Y","expanded_url":"https://twitter.com/bikeindexstolen/status/1300674730798661633/photo/1","type":"photo","sizes":{"thumb":{"w":150,"h":150,"resize":"crop"},"large":{"w":1200,"h":713,"resize":"fit"},"small":{"w":680,"h":404,"resize":"fit"},"medium":{"w":1200,"h":713,"resize":"fit"}}}]},"source":"<a href=\"https://bikeindex.org\" rel=\"nofollow\">stolen_bike_alerter</a>","in_reply_to_status_id":null,"in_reply_to_status_id_str":null,"in_reply_to_user_id":null,"in_reply_to_user_id_str":null,"in_reply_to_screen_name":null,"user":{"id":2548481887,"id_str":"2548481887","name":"Bike Index","screen_name":"bikeindexstolen","location":"","description":"Listing stolen bikes worldwide from https://t.co/cnz9v57sJI","url":"http://t.co/ZcIQS0EzeU","entities":{"url":{"urls":[{"url":"http://t.co/ZcIQS0EzeU","expanded_url":"http://stolen.bikeindex.org","display_url":"stolen.bikeindex.org","indices":[0,22]}]},"description":{"urls":[{"url":"https://t.co/cnz9v57sJI","expanded_url":"http://stolen.bikeindex.org","display_url":"stolen.bikeindex.org","indices":[36,59]}]}},"protected":false,"followers_count":901,"friends_count":186,"listed_count":69,"created_at":"Thu Jun 05 17:17:18 +0000 2014","favourites_count":58,"utc_offset":null,"time_zone":null,"geo_enabled":true,"verified":false,"statuses_count":55301,"lang":null,"contributors_enabled":false,"is_translator":false,"is_translation_enabled":false,"profile_background_color":"C0DEED","profile_background_image_url":"http://abs.twimg.com/images/themes/theme1/bg.png","profile_background_image_url_https":"https://abs.twimg.com/images/themes/theme1/bg.png","profile_background_tile":false,"profile_image_url":"http://pbs.twimg.com/profile_images/505774915660705793/UpEjqnux_normal.jpeg","profile_image_url_https":"https://pbs.twimg.com/profile_images/505774915660705793/UpEjqnux_normal.jpeg","profile_banner_url":"https://pbs.twimg.com/profile_banners/2548481887/1403465498","profile_link_color":"1DA1F2","profile_sidebar_border_color":"C0DEED","profile_sidebar_fill_color":"DDEEF6","profile_text_color":"333333","profile_use_background_image":true,"has_extended_profile":false,"default_profile":true,"default_profile_image":false,"following":false,"follow_request_sent":false,"notifications":false,"translator_type":"none"},"geo":{"type":"Point","coordinates":[44.8735964,-93.2835137]},"coordinates":{"type":"Point","coordinates":[-93.2835137,44.8735964]},"place":{"id":"5527cc189b162d13","url":"https://api.twitter.com/1.1/geo/id/5527cc189b162d13.json","place_type":"city","name":"Richfield","full_name":"Richfield, MN","country_code":"US","country":"United States","contained_within":[],"bounding_box":{"type":"Polygon","coordinates":[[[-93.319039,44.861721],[-93.238909,44.861721],[-93.238909,44.890859],[-93.319039,44.890859]]]},"attributes":{}},"contributors":null,"is_quote_status":false,"repost_count":0,"favorite_count":0,"favorited":false,"reposted":false,"possibly_sensitive":false,"lang":"en"}' }
      let(:social_post) { Tweet.new(platform_response: JSON.parse(platform_response)) }
      it "returns what we expect" do
        expect(tweet.postor).to eq "bikeindexstolen"
        expect(tweet.posted_at).to be_within(1).of Time.at(1598939995)
        expect(tweet.posted_image).to eq "https://pbs.twimg.com/media/EgzsxnGUwAA_SNx.jpg"
        expect(tweet.posted_text).to eq "STOLEN - Black Cannondale Bad Boy in Richfield, MN https://t.co/HskxBZRGv3 https://t.co/h0ULGHBF0Y"
        expect(tweet.postor_avatar).to eq "https://pbs.twimg.com/profile_images/505774915660705793/UpEjqnux_normal.jpeg"
      end
    end
  end

  describe "send_tweet" do
    let(:social_account) { FactoryBot.create(:social_account, social_account_info: {stuff: ""}) }
    let(:social_post) { Tweet.create(body: "testing new system", social_account: social_account, kind: "app_tweet") }
    it "creates a tweet" do
      expect(social_account).to receive(:social_post) { {something: "ffff"} }
      tweet.send_tweet
      tweet.reload
      expect(tweet.platform_response).to eq({"something" => "ffff"})
    end
  end
end
