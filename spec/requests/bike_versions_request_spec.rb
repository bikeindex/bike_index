require "rails_helper"

RSpec.describe BikeVersions::EditsController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bike_versions" }
  let(:bike_version) { FactoryBot.create(:bike_version, owner: current_user) }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.code).to eq("200")
      expect(response).to render_template(:index)
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{bike_version.to_param}"
      expect(response.code).to eq "200"
      expect(response).to render_template(:show)
      bike_version.update(visibility: "user_hidden")
      get "#{base_url}/#{bike_version.to_param}"
      expect(response.code).to eq "200"
      expect(response).to render_template(:show)
    end
    context "superadmin" do
      let(:current_user) { FactoryBot.create(:admin) }
      it "renders" do
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.code).to eq "200"
        expect(response).to render_template(:show)
        bike_version.update(visibility: "user_hidden")
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.code).to eq "200"
        expect(response).to render_template(:show)
      end
    end
    context "no current_user" do
      let(:current_user) { nil }
      let(:bike_version) { FactoryBot.create(:bike_version) }
      it "renders" do
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.code).to eq "200"
        expect(response).to render_template(:show)
        bike_version.update(visibility: "user_hidden")
        expect {
          get "#{base_url}/#{bike_version.to_param}"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "create" do
    let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
    it "creates" do
      expect do
        post base_url, params: {bike_id: bike.id}
      end.to change(BikeVersion, :count).by 1
      expect(flash[:success]).to be_present
      new_bike_version = BikeVersion.last
      expect(new_bike_version.owner_id).to eq current_user.id
      expect(new_bike_version.bike_id).to eq bike.id
    end
    context "not users bike" do
      let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      it "does not create" do
        expect(bike.reload.authorized?(current_user)).to be_falsey
        expect do
          post base_url, params: {bike_id: bike.id}
        end.to change(BikeVersion, :count).by 0
        expect(flash[:error]).to be_present
      end
    end
  end
end
