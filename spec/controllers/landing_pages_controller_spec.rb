require "rails_helper"

RSpec.describe LandingPagesController, type: :controller do
  include_context :page_content_values

  describe "show" do
    let!(:organization) { FactoryBot.create(:organization, short_name: "University") }

    it "renders revised_layout" do
      get :show, params: { organization_id: "university" }
      expect(response.status).to eq(200)
      expect(response).to render_template("show")
      expect(title).to eq "University Bike Registration"
    end

    context "xml request format" do
      it "renders revised_layout (ignoring response format)" do
        get :show, params: { organization_id: organization.slug }, format: :xml
        expect(response.status).to eq(200)
        expect(response).to render_template("show")
        expect(title).to eq "University Bike Registration"
      end
    end
  end
end
