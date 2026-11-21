require "rails_helper"

RSpec.describe Register::OrganizationsController, type: :request do
  let(:organization) { FactoryBot.create(:organization) }
  let(:target_url) { "http://www.example.com/register/#{organization.slug}" }

  it "redirects to registering with the organization, unless /register has its own page" do
    get "/register/uc-merced"
    expect(response).to redirect_to(new_register_path(organization_id: "uc-merced"))
    expect(response.status).to eq 301

    get "/register/landing"
    expect(response).to have_http_status(:ok)
  end

  it "renders a png, linking to the organization's registration" do
    get "/register/#{organization.slug}.png"
    expect(response.status).to eq(200)
    expect(response.media_type).to eq "image/png"
    expect(assigns(:organization)).to eq organization
    expect(assigns(:qr_url)).to eq target_url

    get "/register/#{organization.slug}.png?target=xxxxx"
    expect(assigns(:qr_url)).to eq target_url
  end

  context "target=shop_display" do
    let(:target_url) { "http://www.example.com/organizations/#{organization.slug}/embed?non_stolen=true&shop_display=true" }

    it "links to the embed" do
      get "/register/#{organization.slug}.png?target=shop_display"
      expect(response.status).to eq(200)
      expect(assigns(:qr_url)).to eq target_url
    end
  end

  context "target=landing" do
    let(:target_url) { "http://www.example.com/#{organization.slug}" }

    it "links to the landing page, even without a landing page route" do
      expect(LandingPageOrganizations::SLUGS).to_not include(organization.slug)

      get "/register/#{organization.slug}.png?target=landing"
      expect(response.status).to eq(200)
      expect(assigns(:qr_url)).to eq target_url
    end
  end

  context "unknown organization" do
    it "is not found" do
      get "/register/not-an-organization.png"
      expect(response.status).to eq(404)
    end
  end
end
