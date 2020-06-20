require "rails_helper"

RSpec.describe OrgPublic::LandingController, type: :request do
  let(:base_url) { "/partner/#{current_organization.to_param}/landing" }
  let(:current_organization) { FactoryBot.create(:organization) }

  it "redirects" do
    expect(current_organization.landing_html?).to be_falsey
    expect do
      get base_url
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  context "organization has landing page" do
    let(:current_organization) { FactoryBot.create(:organization, name: "university", landing_html: "<div>Something</div>") }
    it "renders" do
      expect(current_organization.landing_html?).to be_truthy
      expect(LandingPages::ORGANIZATIONS).to include(current_organization.slug)
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template :index
      expect(assigns(:current_organization)).to eq current_organization
      expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
    end
  end

  context "logged_in_as_organization_member" do
    include_context :request_spec_logged_in_as_organization_member
    describe "index" do
      it "renders, even without landing_html" do
        expect(current_organization.landing_html?).to be_falsey
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:passive_organization)).to eq current_organization
      end
    end
  end
end
