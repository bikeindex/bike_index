require "rails_helper"

base_url = "/membership"
RSpec.describe MembershipsController, type: :request do
  let(:re_record_interval) { 30.days }

  describe "show" do
    it "redirects to blog" do
      get base_url
      expect(response).to redirect_to "/news/bike-index-membership"
    end
  end

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
        let!(:membership) { FactoryBot.create(:membership, user: current_user) }
        it "redirects to edit" do
          expect(current_user.reload.membership_active).to be_present

          get "#{base_url}/new"
          expect(response).to redirect_to "/membership/edit"
        end
      end
      context "user has an inactive membership" do
        let!(:membership) { FactoryBot.create(:membership, user: current_user, start_at: 1.year.ago, end_at: 1.month.ago) }
        it "redirects to edit" do
          expect(current_user.reload.membership_active).to be_blank

          get "#{base_url}/new"
          expect(response.code).to eq("200")
          expect(response).to render_template("new")
          expect(flash).to_not be_present
        end
      end
    end
  end

  describe "create" do
    let!(:stripe_price) { FactoryBot.create(:stripe_price_basic) }
    let(:create_params) do
      {
        currency: "usd",
        membership: {set_interval: "monthly", level: "basic"}
      }
    end
    let(:target_stripe_subscription) do
      {
        stripe_price_stripe_id: stripe_price.stripe_id,
        currency_enum: "usd",
        membership_level: "basic",
        interval: "monthly",
        start_at: nil,
        stripe_status: nil,
        stripe_id: nil,
        end_at: nil,
        user_id: nil
      }
    end

    it "creates a stripe_subscription" do
      VCR.use_cassette("MembershipsController-create-no_user", match_requests_on: [:method], re_record_interval: re_record_interval) do
        expect {
          post base_url, params: create_params
        }.to change(StripeSubscription, :count).by 1
        expect(Membership.count).to eq 0
        stripe_subscription = StripeSubscription.last
        expect(stripe_subscription).to match_hash_indifferently target_stripe_subscription
        expect(stripe_subscription.payments.count).to eq 1
        expect(response).to redirect_to(/https:..checkout.stripe.com/)
      end
    end

    context "logged in" do
      include_context :request_spec_logged_in_as_user

      it "creates a stripe_subscription" do
        Sidekiq::Job.drain_all
        ActionMailer::Base.deliveries = []
        VCR.use_cassette("MembershipsController-create-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect {
            post base_url, params: create_params
          }.to change(StripeSubscription, :count).by 1
          expect(Membership.count).to eq 0
          stripe_subscription = StripeSubscription.last
          expect(stripe_subscription).to match_hash_indifferently target_stripe_subscription.merge(user_id: current_user.id)
          expect(stripe_subscription.payments.count).to eq 1
          expect(response).to redirect_to(/https:..checkout.stripe.com/)
          # Verify that no emails are created
          Sidekiq::Job.drain_all
          expect(ActionMailer::Base.deliveries.empty?).to be_truthy
        end
      end
      context "with yearly archived price" do
        # Accidental price on production that is incorrect
        let!(:stripe_price_archived) { FactoryBot.create(:stripe_price_basic_archived) }
        let!(:stripe_price) { FactoryBot.create(:stripe_price_basic_yearly) }
        let(:create_yearly_params) { {currency: "usd", membership: {set_interval: "yearly", level: "basic"}} }
        let(:target_stripe_yearly) { target_stripe_subscription.merge(interval: "yearly", user_id: current_user.id) }

        it "creates a stripe_subscription" do
          Sidekiq::Job.drain_all
          ActionMailer::Base.deliveries = []
          VCR.use_cassette("MembershipsController-create-yearly-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
            expect {
              post base_url, params: create_yearly_params
            }.to change(StripeSubscription, :count).by 1
            expect(Membership.count).to eq 0
            stripe_subscription = StripeSubscription.last
            expect(stripe_subscription).to match_hash_indifferently target_stripe_yearly
            expect(stripe_subscription.payments.count).to eq 1
            expect(response).to redirect_to(/https:..checkout.stripe.com/)
            # Verify that no emails are created
            Sidekiq::Job.drain_all
            expect(ActionMailer::Base.deliveries.empty?).to be_truthy
          end
        end
      end

      context "with invalid currency" do
        let(:modified_params) { create_params.merge(currency: "xxx") }

        it "creates a stripe_subscription" do
          VCR.use_cassette("MembershipsController-create-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
            expect {
              post base_url, params: modified_params
            }.to change(StripeSubscription, :count).by 1
            expect(Membership.count).to eq 0
            stripe_subscription = StripeSubscription.last
            expect(stripe_subscription).to match_hash_indifferently target_stripe_subscription.merge(user_id: current_user.id)
            expect(stripe_subscription.payments.count).to eq 1
            expect(response).to redirect_to(/https:..checkout.stripe.com/)
          end
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
  end

  describe "edit" do
    it "sets return to, redirects to log in" do
      get "#{base_url}/edit"
      expect(response).to redirect_to new_session_path
      expect(flash[:error]).to be_present
      expect(session[:return_to]).to match(/membership\/edit/)
    end

    context "logged in" do
      include_context :request_spec_logged_in_as_user

      it "redirects to new membership" do
        get "#{base_url}/edit"
        expect(response).to redirect_to new_membership_path
        expect(flash[:notice]).to match(/active/)
      end

      context "with admin managed active membership" do
        let!(:membership) { FactoryBot.create(:membership, user: current_user) }
        it "redirects to my_account" do
          expect(current_user.reload.membership_active.admin_managed?).to be_truthy

          get "#{base_url}/edit"
          expect(response).to redirect_to my_account_path
          expect(flash[:notice]).to match(/free membership/i)
        end
      end

      context "with stripe membership" do
        let!(:stripe_subscription) { FactoryBot.create(:stripe_subscription_active, user: current_user) }

        it "redirects to my_account" do
          current_user.update(stripe_id: "cus_RohIc4uZhMPzxN")
          expect(current_user.reload.membership_active.admin_managed?).to be_falsey

          VCR.use_cassette("MembershipsController-edit-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
            get "#{base_url}/edit"
            expect(response).to redirect_to(/https:\/\/billing.stripe.com\/p\/session/)
          end
        end
      end
    end
  end
end
