require "rails_helper"

base_url = "/sales"
RSpec.describe SalesController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:item) { FactoryBot.create(:bike, :with_primary_activity, :with_ownership_claimed, user:) }
  let(:ownership) { item.current_ownership }
  let(:current_user) { user }

  describe "new" do
    it "renders" do
      expect(ownership.id).to be_present
      get "#{base_url}/new?ownership_id=#{ownership.id}"
      expect(response).to render_template(:new)
      expect(flash).to be_blank
    end
    context "with an existing sale record" do
      it "IDK What to do about this!"
    end

    context "without a current_user" do
      let(:current_user) { nil }
      it "redirects" do
        get "#{base_url}/new?ownership_id=#{ownership.id}"
        expect(response).to redirect_to(:new_session)
        expect(flash[:error].match(/log in/i)).to be_present
      end
      context "without a found ownership" do
        it "redirects" do
          get "#{base_url}/new?ownership_id=3333333"
          expect(response.status).to eq 404
        end
      end
    end
  end

  describe "create" do
    it "creates a sale" do

    end
  end
end
