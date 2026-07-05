require "rails_helper"

RSpec.describe ComponentsController, type: :request do
  describe "index" do
    let!(:ctype) { FactoryBot.create(:ctype, name: "Headset") }

    context "csv" do
      it "gets a csv" do
        get "/components.csv"
        expect(response.status).to eq(200)
        expect(response.content_type).to match("text/csv")
        expect(response.body).to start_with("name,secondary_name,has_multiple_locations,group")
        expect(response.body).to include("Headset")
      end
    end
  end
end
