require "rails_helper"

RSpec.describe BikeVersions::EditsController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bike_versions/#{bike_version.to_param}/edit" }
  let!(:bike_version) { FactoryBot.create(:bike_version, owner: current_user) }
  let(:edit_templates) do
    {
      bike_details: "Details",
      photos: "Photos",
      drivetrain: "Wheels and Drivetrain",
      accessories: "Accessories and Components",
      remove: "Hide or Delete"
    }
  end

  it "renders" do
    get base_url
    expect(response.code).to eq "200"
    expect(response).to render_template("bikes_edit/bike_details")
    expect(assigns(:page_id)).to eq "bike_versions_edits_show"
    bike_version.update(visibility: "user_hidden")
    get base_url
    expect(response.code).to eq "200"
    expect(response).to render_template("bikes_edit/bike_details")
    expect(assigns(:edit_templates)).to eq edit_templates.as_json
  end
  context "superadmin" do
    let!(:bike_version) { FactoryBot.create(:bike_version) }
    let(:current_user) { FactoryBot.create(:superuser) }
    it "renders" do
      expect(bike_version.authorized?(current_user)).to be_truthy
      expect(bike_version.owner_id).to_not eq current_user.id
      get base_url
      expect(response.code).to eq "200"
      expect(response).to render_template("bikes_edit/bike_details")
      bike_version.update(visibility: "user_hidden")
      get base_url
      expect(response.code).to eq "200"
      expect(response).to render_template("bikes_edit/bike_details")
      expect(assigns(:edit_templates)).to eq edit_templates.as_json
    end
  end
  context "no current_user" do
    let!(:bike_version) { FactoryBot.create(:bike_version) }
    it "renders" do
      Flipper.enable :bike_versions
      expect(bike_version.authorized?(current_user)).to be_falsey
      get base_url
      expect(response).to redirect_to(bike_version_path(bike_version))
      expect(flash[:error]).to be_present
      bike_version.update(visibility: "user_hidden")
      get base_url
      expect(response.status).to eq 404
    end
  end
end
