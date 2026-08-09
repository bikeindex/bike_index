# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Data API", type: :request do
  include_context :admin_doorkeeper_token

  shared_examples "requires admin_data superuser" do
    context "no token" do
      it "returns 401" do
        get url
        expect(response.status).to eq 401
        expect(json_result[:error]).to eq "OAuth token required"
      end
    end

    context "token from the wrong app" do
      before { stub_const("API::TokenAuthenticatable::ADMIN_DOORKEEPER_APP_ID", doorkeeper_app.id + 1) }
      it "returns 403" do
        get url, params: token_param
        expect(response.status).to eq 403
        expect(json_result[:error]).to eq "Unauthorized application"
      end
    end

    context "token for a non-superuser" do
      it "returns 403" do
        get url, params: token_param
        expect(response.status).to eq 403
        expect(json_result[:error]).to eq "Not permitted"
      end
    end

    context "token for a user with an unrelated superuser ability" do
      before { FactoryBot.create(:superuser_ability, user: token_user, controller_name: "bikes") }
      it "returns 403" do
        get url, params: token_param
        expect(response.status).to eq 403
      end
    end
  end

  describe "sidekiq" do
    let(:url) { "/api/admin_data/sidekiq" }
    include_examples "requires admin_data superuser"

    context "token for an admin_data superuser" do
      before { FactoryBot.create(:superuser_ability, user: token_user, controller_name: "admin_data") }
      it "returns the sidekiq payload" do
        get url, params: token_param
        expect(response.status).to eq 200
        expect(json_result.keys).to match_array(%w[stats queues processes retries_by_class dead_by_class])
        expect(json_result[:stats].keys).to include("enqueued", "processed", "retry_size")
      end
    end

    context "universal superuser" do
      let(:token_user) { FactoryBot.create(:superuser) }
      it "returns 200" do
        get url, params: token_param
        expect(response.status).to eq 200
      end
    end
  end

  describe "pghero" do
    let(:url) { "/api/admin_data/pghero" }
    include_examples "requires admin_data superuser"

    context "token for an admin_data superuser" do
      before { FactoryBot.create(:superuser_ability, user: token_user, controller_name: "admin_data") }
      it "returns the pghero payload" do
        get url, params: token_param
        expect(response.status).to eq 200
        expect(json_result.keys).to include("query_stats_enabled", "database_size", "index_usage")
      end
    end
  end
end
