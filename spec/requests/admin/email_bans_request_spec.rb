# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::EmailBansController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  base_url = "/admin/email_bans"

  describe "#index" do
    let!(:email_ban) { FactoryBot.create(:email_ban) }

    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:collection).pluck(:id)).to eq([email_ban.id])
    end
  end
end
