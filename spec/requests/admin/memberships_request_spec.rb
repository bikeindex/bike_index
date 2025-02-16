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
      {user_id: user.id, start_at: nil, kind: "plus", end_at: nil, creator: current_user,
       status: "pending_status"}
    end
    it "creates" do
      expect do
        post base_url, params: {membership: {kind: "plus", user_email: " #{user.email.upcase} "}}
      end.to change(Membership, :count).by 1
      expect(Membership.last).to match_hash_indifferently(target_attrs)
    end
    context "with a start_at" do
      it "creates" do
        expect do
          post base_url, params: {
            membership: {
              kind: "plus", user_email: " #{user.email.upcase} ", start_at: Time.current.iso8601
            }
          }
        end.to change(Membership, :count).by 1
        membership = Membership.last
        expect(membership).to match_hash_indifferently(target_attrs.except(:start_at).merge(status: "active_status"))
        expect(membership.start_at).to be_within(1).of Time.current
      end
    end
  end

  describe "update" do
    let(:membership) { FactoryBot.create(:membership) }
    let(:start_at) { "2025-02-05T23:00:00" }
    let(:end_at) { "2026-02-05T23:00:00" }
    it "updates" do
      expect(membership.kind).to eq "basic"
      og_user_id = membership.user_id
      expect(membership.end_at).to be_blank
      patch "#{base_url}/#{membership.id}", params: {
        membership: {kind: "plus", user_email: "ffff", start_at:, end_at:}
      }
      expect(flash[:success]).to be_present
      expect(membership.reload.user_id).to eq og_user_id
      expect(membership.kind).to eq "plus"
      expect(membership.start_at).to match_time TimeParser.parse(start_at)
      expect(membership.end_at).to match_time TimeParser.parse(end_at)
    end
  end
end
