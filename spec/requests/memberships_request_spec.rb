require "rails_helper"

base_url = "/membership"
RSpec.describe MembershipsController, type: :request do
  let(:re_record_interval) { 30.days }

  describe "new" do
    context "user not logged in" do
      it "renders" do
        get "#{base_url}/new"
        expect(response.code).to eq("200")
        expect(response).to render_template("new")
        expect(flash).to_not be_present
      end
    end
    context "with user" do
      include_context :request_spec_logged_in_as_user
      it "renders" do
        get "#{base_url}/new"
        expect(response.code).to eq("200")
        expect(response).to render_template("new")
        expect(flash).to_not be_present
      end
      context "user has an active membership" do
        it "redirects to edit"
      end
    end
  end

  describe "create" do
    let!(:stripe_price) { FactoryBot.create(:stripe_price_basic) }
    let(:create_params) do
      {
        currency: "usd",
        membership: {set_interval: "monthly", kind: "basic"}
      }
    end
    let(:target_stripe_subscription) do
      {
        stripe_price_stripe_id: stripe_price.stripe_id,
        currency_enum: "usd",
        membership_kind: "basic",
        interval: "monthly",
        start_at: nil,
        stripe_status: nil,
        stripe_id: nil,
        end_at: nil,
        user_id: nil
      }
    end

    context "logged in" do
      include_context :request_spec_logged_in_as_user

      it "creates a stripe_subscription" do
        VCR.use_cassette("MembershipsController-create-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect {
            post base_url, params: create_params
          }.to change(StripeSubscription, :count).by 1
          expect(Membership.count).to eq 0
          stripe_subscription = StripeSubscription.last
          expect(stripe_subscription).to match_hash_indifferently target_stripe_subscription.merge(user_id: current_user.id)
          expect(stripe_subscription.payments.count).to eq 1
          expect(response).to redirect_to(/https:..checkout.stripe.com/)
        end
      end

      context "with invalid currency" do
        let(:modified_params) { create_params.merge(currency: "xxx") }

        it "creates a stripe_subscription" do
        end
      end
    end
  end

  describe "success" do
    it "renders" do
      get "#{base_url}/success"
      expect(response.code).to eq("200")
      expect(response).to render_template("success")
      expect(flash).to_not be_present
    end
    context "with checkout id" do
      it "updates the checkout"
    end
  end
end
