require "rails_helper"

RSpec.describe Admin::TweetsController, type: :controller do
  let(:subject) { FactoryBot.create(:tweet) }
  let(:user) { FactoryBot.create(:admin) }
  before { set_current_user(user) }

  describe "index" do
    it "renders" do
      get :index
      expect(response).to be_ok
      expect(response).to render_template(:index)
    end
  end

  describe "edit" do
    it "renders" do
      get :edit, params: { id: subject.twitter_id }
      expect(response).to be_ok
      expect(response).to render_template(:edit)
    end
  end

  describe "new" do
    it "renders" do
      get :new
      expect(response).to be_ok
      expect(response).to render_template(:new)
    end
  end

  describe "create" do
    xit "gets the tweet from twitter" do
      # expect do
      post :create, params: { tweet: { twitter_id: "839247587521679360" } }
      # end.to change(Tweet, :count).by(1)
      expect(response).to redirect_to edit_admin_tweet_url
      expect(flash[:success]).to be_present
      tweet = assigns(:tweet)
    end
  end

  describe "#destroy" do
    context "given a successful deletion" do
      it "deletes the tweet, redirects to tweet index url with an appropriate flash" do
        tweet = FactoryBot.create(:tweet)

        delete :destroy, params: { id: tweet.id }

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

        delete :destroy, params: { id: tweet.id }

        expect(response).to redirect_to(edit_admin_tweet_url)
        expect(flash[:info]).to be_blank
        expect(flash[:error]).to match("Could not delete")
      end
    end
  end
end
