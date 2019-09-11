require "rails_helper"

RSpec.describe Admin::TwitterAccountsController, type: :controller, vcr: true do
  include_context :logged_in_as_super_admin

  describe "index" do
    it "renders" do
      get :index
      expect(response).to be_success
      expect(response).to render_template(:index)
    end
  end

  describe "edit" do
    it "renders" do
      twitter_account = FactoryBot.create(:twitter_account_1)
      get :edit, id: twitter_account.id
      expect(response).to be_success
      expect(response).to render_template(:edit)
    end
  end

  describe "new" do
    it "renders" do
      get :new
      expect(response).to be_success
      expect(response).to render_template(:new)
    end
  end

  describe "create" do
    it "gets the tweet from twitter" do
      twitter_account_attrs = FactoryBot.attributes_for(:twitter_account_1)
      expect(TwitterAccount.count).to eq(0)

      post :create, twitter_account: twitter_account_attrs

      expect(TwitterAccount.count).to eq(1)
      expect(response).to redirect_to(admin_twitter_account_url(TwitterAccount.first.id))
      expect(flash[:error]).to be_blank
    end
  end

  describe "#destroy" do
    context "given a successful deletion" do
      it "deletes the tweet, redirects to tweet index url with an appropriate flash" do
        twitter_account = FactoryBot.create(:twitter_account_1)

        delete :destroy, id: twitter_account.id

        expect(response).to redirect_to(admin_twitter_accounts_url)
        expect(flash[:error]).to be_blank
        expect(flash[:info]).to match("deleted")
      end
    end

    context "given a failed deletion" do
      it "redirects to tweet edit url with an appropriate flash" do
        twitter_account = FactoryBot.create(:twitter_account_1)
        allow(twitter_account).to receive(:destroy).and_return(false)
        allow(TwitterAccount)
          .to(receive(:find).with(twitter_account.id.to_s).and_return(twitter_account))

        delete :destroy, id: twitter_account.id

        expect(response).to redirect_to(edit_admin_twitter_account_url(twitter_account))
        expect(flash[:info]).to be_blank
        expect(flash[:error]).to match("Could not delete")
      end
    end
  end
end
