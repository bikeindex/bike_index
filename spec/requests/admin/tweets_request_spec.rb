require "rails_helper"

RSpec.describe Admin::TweetsController, type: :request do
  let(:subject) { FactoryBot.create(:tweet, kind: "app_tweet", twitter_id: "fake-id-to-skip-validations") }
  let(:base_url) { "/admin/tweets/" }
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response).to be_ok
      expect(response).to render_template(:index)
      expect(flash).to be_blank
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{subject.twitter_id}"
      expect(response).to be_ok
      expect(response).to render_template(:show)
      expect(flash).to be_blank
      expect(assigns(:tweet)).to eq subject
    end
    context "imported_tweet" do
      let(:subject) { FactoryBot.create(:tweet, kind: "imported_tweet") }
      it "redirects to edit" do
        subject.reload
        expect(subject.kind).to eq "imported_tweet"
        get "#{base_url}/#{subject.id}"
        expect(assigns(:tweet)).to eq subject
        expect(response).to redirect_to edit_admin_tweet_path(subject.id)
      end
    end
  end

  describe "edit" do
    it "redirects" do
      subject.reload
      expect(subject.kind).to eq "app_tweet"
      get "#{base_url}/#{subject.id}/edit"
      expect(response).to redirect_to admin_tweet_path(subject.id)
    end
    context "imported_tweet" do
      let(:subject) { FactoryBot.create(:tweet, kind: "imported_tweet") }
      it "renders" do
        get "#{base_url}/#{subject.id}/edit"
        expect(response).to be_ok
        expect(response).to render_template(:edit)
        expect(flash).to be_blank
      end
    end
  end

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response).to be_ok
      expect(response).to render_template(:new)
      expect(flash).to be_blank
    end
  end

  describe "create" do
    # it "tweets" do
    #   # TODO: Actually test
    # end
    # context "imported_tweet" do
    #   it "gets the tweet from twitter" do
    #     # TODO: Actually test
    #   end
    # end
  end

  describe "#destroy" do
    context "given a successful deletion" do
      it "deletes the tweet, redirects to tweet index url with an appropriate flash" do
        tweet = FactoryBot.create(:tweet)

        delete "#{base_url}/#{tweet.id}"

        expect(response).to redirect_to(admin_tweets_url)
        expect(flash[:error]).to be_blank
        expect(flash[:info]).to match("deleted")
      end
    end

    context "given a failed deletion" do
      it "redirects to tweet edit url with an appropriate flash" do
        tweet = FactoryBot.create(:tweet)
        allow(tweet).to receive(:destroy).and_return(false)
        allow(Tweet).to receive(:friendly_find).with(tweet.id.to_s).and_return(tweet)

        delete "#{base_url}/#{tweet.id}"

        expect(response).to redirect_to(edit_admin_tweet_url)
        expect(flash[:info]).to be_blank
        expect(flash[:error]).to match("Could not delete")
      end
    end
  end
end
