# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::UserBansController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  base_url = "/admin/user_bans"

  describe "#index" do
    let!(:user_ban) { UserBan.create(user: FactoryBot.create(:user), creator: current_user, reason: :abuse) }

    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:collection).pluck(:id)).to eq([user_ban.id])
    end
  end
end
