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

  describe "update" do
    let(:twitter_account) { FactoryBot.create(:twitter_account_1, active: false) }
    before { twitter_account.set_error("Something") }
    it "updates without check_credentials" do
      expect(twitter_account.errored?).to be_truthy
      expect_any_instance_of(TwitterAccount).to_not receive(:twitter_client)
      patch :update,
            id: twitter_account.id,
            check_credentials: "0",
            twitter_account: { append_block: "Something special" }
      twitter_account.reload
      expect(twitter_account.append_block).to eq "Something special"
      expect(twitter_account.errored?).to be_truthy
      expect(twitter_account.active).to be_falsey
    end
    context "switching to active" do
      let(:twitter_client) { OpenStruct.new(verify_credentials: false) }
      it "updates and checks_credentials" do
        expect(twitter_account.errored?).to be_truthy
        allow_any_instance_of(TwitterAccount).to receive(:twitter_client) { twitter_client }
        expect(twitter_client).to receive(:verify_credentials) { true }
        patch :update,
              id: twitter_account.id,
              check_credentials: true,
              twitter_account: { active: true }
        twitter_account.reload
        expect(twitter_account.active).to be_truthy
        expect(twitter_account.errored?).to be_falsey
      end
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
