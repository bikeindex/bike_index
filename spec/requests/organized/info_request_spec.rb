require "rails_helper"

RSpec.describe Organized::InfoController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/info" }

  context "logged_in_as_organization_user" do
    include_context :request_spec_logged_in_as_organization_user

    it "renders, with the way back when there is one" do
      get base_url, params: {return_to: "/lightspeed_interface"}
      expect(response.status).to eq 200
      expect(response.body).to include "#{current_organization.name} is active"
      expect(Capybara.string(response.body)).to have_link "Continue where you were", href: "/lightspeed_interface"

      ["//evil.com", "/\\evil.com", "/\t/evil.com", "https://evil.com"].each do |return_to|
        get base_url, params: {return_to:}
        expect(response.body).to_not include "Continue where you were"
      end
    end
  end

  context "not a member" do
    include_context :request_spec_logged_in_as_user_if_present
    let(:current_organization) { FactoryBot.create(:organization) }

    it "redirects" do
      get base_url
      expect(response).to redirect_to my_account_path
      expect(flash[:error]).to be_present
    end
  end
end
