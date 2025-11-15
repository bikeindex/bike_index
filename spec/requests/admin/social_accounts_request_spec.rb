require "rails_helper"

base_url = "/admin/social_accounts"
RSpec.describe Admin::SocialAccountsController, type: :request, vcr: true do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response).to be_ok
      expect(response).to render_template(:index)
    end
  end

  describe "edit" do
    it "renders" do
      social_account = FactoryBot.create(:social_account_1)
      get "#{base_url}/#{social_account.id}/edit"
      expect(response).to be_ok
      expect(response).to render_template(:edit)
    end
  end

  describe "update" do
    let(:social_account) { FactoryBot.create(:social_account_1, active: false) }
    before { social_account.set_error("Something") }
    it "updates without check_credentials" do
      expect(social_account.errored?).to be_truthy
      expect_any_instance_of(SocialAccount).to_not receive(:twitter_client)
      patch "#{base_url}/#{social_account.id}",
        params: {
          check_credentials: "0",
          social_account: {append_block: "Something special"}
        }
      social_account.reload
      expect(social_account.append_block).to eq "Something special"
      expect(social_account.errored?).to be_truthy
      expect(social_account.active).to be_falsey
    end
    context "switching to active" do
      let(:twitter_client) { OpenStruct.new(verify_credentials: false) }
      it "updates and checks_credentials" do
        expect(social_account.errored?).to be_truthy
        allow_any_instance_of(SocialAccount).to receive(:twitter_client) { twitter_client }
        expect(twitter_client).to receive(:verify_credentials) { true }
        patch "#{base_url}/#{social_account.id}",
          params: {
            check_credentials: true,
            social_account: {active: true}
          }
        social_account.reload
        expect(social_account.active).to be_truthy
        expect(social_account.errored?).to be_falsey
      end
    end
  end

  describe "#destroy" do
    context "given a successful deletion" do
      it "deletes the tweet, redirects to tweet index url with an appropriate flash" do
        social_account = FactoryBot.create(:social_account_1)

        delete "#{base_url}/#{social_account.id}"

        expect(response).to redirect_to(admin_social_accounts_url)
        expect(flash[:error]).to be_blank
        expect(flash[:info]).to match("deleted")
      end
    end

    context "given a failed deletion" do
      it "redirects to tweet edit url with an appropriate flash" do
        social_account = FactoryBot.create(:social_account_1)
        allow(social_account).to receive(:destroy).and_return(false)
        allow(SocialAccount)
          .to(receive(:find).with(social_account.id.to_s).and_return(social_account))

        delete "#{base_url}/#{social_account.id}"

        expect(response).to redirect_to(edit_admin_social_account_url(social_account))
        expect(flash[:info]).to be_blank
        expect(flash[:error]).to match("Could not delete")
      end
    end
  end
end
