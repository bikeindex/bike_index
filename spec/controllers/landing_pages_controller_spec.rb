require "spec_helper"

describe LandingPagesController do
  include_context :page_content_values
  describe "show" do
    let!(:organization) { FactoryBot.create(:organization, short_name: "University") }
    it "renders revised_layout" do
      get :show, organization_id: "university"
      expect(response.status).to eq(200)
      expect(response).to render_template("show")
      expect(title).to eq "University Bike Registration"
    end
    context "xml request format" do
      it "renders revised_layout (ignoring response format)" do
        get :show, organization_id: organization.slug, format: :xml
        expect(response.status).to eq(200)
        expect(response).to render_template("show")
        expect(title).to eq "University Bike Registration"
      end
    end
  end

  %w[for_shops for_advocacy for_law_enforcement for_schools ascend campus_packages].each do |landing_type|
    describe landing_type do
      it "renders with correct title" do
        get landing_type.to_sym, preview: true
        expect(response.status).to eq(200)
        expect(response).to render_template(landing_type)
        if landing_type == "for_advocacy"
          expect(title).to eq "Bike Index for Advocacy Organizations"
        elsif landing_type == "ascend"
          expect(title).to eq "Ascend POS on Bike Index"
        elsif landing_type == "campus_packages"
          expect(title).to eq "Campus packages"
        else
          expect(title).to eq "Bike Index #{landing_type.titleize.gsub(/\AF/, "f")}"
        end
      end
    end
  end
end
