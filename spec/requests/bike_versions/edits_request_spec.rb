require "rails_helper"

RSpec.describe BikeVersionEditsController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bike_versions/#{bike_version}/edit" }
  let!(:bike_version) { FactoryBot.create(:bike_version, owner: current_user) }

  describe "show" do
    it "renders" do
      get base_url
      expect(response.code).to eq "200"
      expect(response).to render_template("bikes_edit/bike_details")
      bike_version.update(visibility: "user_hidden")
      get base_url
      expect(response.code).to eq "200"
      expect(response).to render_template("bikes_edit/bike_details")
    end
    context "superadmin" do
      let(:current_user) { FactoryBot.create(:admin) }
      it "renders" do
        get base_url
        expect(response.code).to eq "200"
        expect(response).to render_template("bikes_edit/bike_details")
        bike_version.update(visibility: "user_hidden")
        get base_url
        expect(response.code).to eq "200"
        expect(response).to render_template("bikes_edit/bike_details")
      end
    end
    context "no current_user" do
      let!(:bike_version) { FactoryBot.create(:bike_version) }
      it "renders" do
        get base_url
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(bike_version_path(bike_version))
        bike_version.update(visibility: "user_hidden")
        expect {
          get "#{base_url}/#{bike_version.to_param}"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
