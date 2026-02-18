require "rails_helper"

RSpec.describe Admin::MembershipsController, type: :request do
  base_url = "/admin/memberships/"
  let(:membership) { FactoryBot.create(:membership) }

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      expect(membership).to be_present
      get base_url
      expect(response).to render_template :index
    end
  end

  describe "show" do
    it "renders" do
      expect(membership).to be_present
      get "#{base_url}/#{membership.id}"
      expect(response).to render_template :show
    end
  end

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response).to render_template :new
    end
  end

  describe "create" do
    let!(:user) { FactoryBot.create(:user_confirmed) }
    let(:target_attrs) do
      {user_id: user.id, start_at: nil, level: "plus", end_at: nil, creator: current_user,
       status: "pending"}
    end
    it "creates" do
      expect do
        post base_url, params: {
          membership: {level: "plus", user_email: " #{user.email.upcase} "}
        }
      end.to change(Membership, :count).by 1
      expect(Membership.last).to match_hash_indifferently(target_attrs)
    end
    context "no matching user" do
      it "doesn't create" do
        expect do
          post base_url, params: {
            membership: {level: "plus", user_email: "unknownemail@example.com"}
          }
        end.to change(Membership, :count).by 0
      end
    end
    context "with a start_at" do
      it "creates" do
        expect do
          post base_url, params: {
            membership: {
              level: "plus", user_email: " #{user.email.upcase} ", start_at: Time.current.iso8601
            }
          }
        end.to change(Membership, :count).by 1
        membership = Membership.last
        expect(membership).to match_hash_indifferently(target_attrs.except(:start_at).merge(status: "active"))
        expect(membership.start_at).to be_within(5).of Time.current
      end
    end
  end

  describe "update" do
    let(:membership) { FactoryBot.create(:membership) }
    let(:start_at) { "2025-02-05T23:00:00" }
    let(:end_at) { "2026-02-05T23:00:00" }
    let(:update_params) do
      {level: "plus", user_email: "ffff", start_at:, end_at:}
    end
    it "updates" do
      expect(membership.level).to eq "basic"
      og_user_id = membership.user_id
      expect(membership.end_at).to be_blank
      patch "#{base_url}/#{membership.id}", params: {
        membership: update_params
      }
      expect(flash[:success]).to be_present
      expect(membership.reload.user_id).to eq og_user_id
      expect(membership.level).to eq "plus"
      expect(membership.start_at).to match_time Binxtils::TimeParser.parse(start_at)
      expect(membership.end_at).to match_time Binxtils::TimeParser.parse(end_at)
    end
    context "update_stripe" do
      let(:membership) { FactoryBot.create(:membership, level: "plus", start_at: nil, creator: nil) }
      let!(:stripe_price_yearly) { FactoryBot.create(:stripe_price_basic_yearly_cad) }
      let!(:stripe_subscription) do
        FactoryBot.create(:stripe_subscription, membership:, stripe_id: "sub_0QvTBbm0T0GBfX0vwdulsIAm", start_at: nil, end_at: nil)
      end
      let(:start_at) { Time.at(1740271007) } # 2025-2-22 18:36
      let(:target_stripe_subscription_attrs) do
        {membership_level: "basic", interval: "yearly", stripe_status: "active", start_at:, end_at: nil,
         stripe_price_stripe_id: stripe_price_yearly.stripe_id, currency_enum: "cad"}
      end

      it "updates stripe" do
        expect(membership.reload.start_at).to be_blank
        expect(membership.status).to eq "pending"
        expect(stripe_subscription.reload.active?).to be_falsey
        expect(stripe_subscription.interval).to eq "monthly"

        VCR.use_cassette("admin-memberships_controller-update_stripe", match_requests_on: [:method]) do
          patch "#{base_url}/#{membership.id}", params: {update_from_stripe: "1"}
          expect(flash[:success]).to be_present

          expect(membership.reload.status).to eq "active"
          expect(membership.level).to eq "basic"
          expect(membership.start_at).to be_within(1).of start_at

          expect(stripe_subscription.reload.active?).to be_truthy
          expect(stripe_subscription).to match_hash_indifferently target_stripe_subscription_attrs
          expect(stripe_subscription.payments.count).to eq 0
        end
      end
    end
  end
end
