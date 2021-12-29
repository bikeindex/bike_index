require "rails_helper"

RSpec.describe BikesController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bike_versions" }
  let(:current_user) { bike_version.owner }
  let(:bike_version) { FactoryBot.create(:bike_version) }

  # describe "index" do
  #   it "renders" do
  #     get base_url
  #     expect(response.code).to eq("200")
  #     expect(response).to render_template(:index)
  #   end
  # end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{bike_version.to_param}"
      expect(response.code).to eq "200"
      expect(response).to render_template(:show)
      bike_version.update(user_hidden: true)
      get "#{base_url}/#{bike_version.to_param}"
      expect(response.code).to eq "200"
      expect(response).to render_template(:show)
      bike_version.update(user_hidden: false)
      bike_version.destroy
      expect {
        get "#{base_url}/#{bike_version.to_param}"
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
    context "superadmin" do
      let(:current_user) { FactoryBot.create(:admin) }
      it "renders" do
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.code).to eq "200"
        expect(response).to render_template(:show)
        bike_version.update(user_hidden: true)
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.code).to eq "200"
        expect(response).to render_template(:show)
        bike_version.update(user_hidden: false)
        bike_version.destroy
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.code).to eq "200"
        expect(response).to render_template(:show)
      end
    end
    context "no current_user" do
      let(:current_user) { nil }
      it "renders" do
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.code).to eq "200"
        expect(response).to render_template(:show)
        bike_version.update(user_hidden: true)
        expect {
          get "#{base_url}/#{bike_version.to_param}"
        }.to raise_error(ActiveRecord::RecordNotFound)
        bike_version.update(user_hidden: true)
        bike_version.destroy
        expect {
          get "#{base_url}/#{bike_version.to_param}"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
