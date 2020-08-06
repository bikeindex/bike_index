require "rails_helper"

RSpec.describe Admin::PaintsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  base_url = "/admin/paints"
  let(:paint) { FactoryBot.create(:paint) }

  describe "index" do
    it "renders" do
      expect(paint).to be_present
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "edit" do
    it "renders" do
      get "#{paint.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe "update" do
    let(:paint) { FactoryBot.create(:paint, "avacado sunset anthracite") }
    let!(:bike) { FactoryBot.create(:bike, paint: paint, primary_frame_color: black) }
    let(:black) { Color.black }
    let!(:green) { FactoryBot.create(:color, name: "Green") }
    let!(:yellow) { FactoryBot.create(:color, name: "Yellow or Gold") }
    let!(:gray) { FactoryBot.create(:color, name: "Silver, Gray or Bare Metal") }

    let(:paint_attributes) do
      {
        name: "New name!",
        color_id: green.id,
        secondary_color_id: yellow.id,
        tertiary_color_id: gray.id
      }
    end
    it "updates the bikes" do
      expect(bike.paint).to eq paint
      expect(bike.primary_frame_color).to eq black
      expect(paint.color).to eq black
      expect(paint.secondary_color).to be_blank
      expect(paint.tertiary_color).to be_blank
      put "#{base_url}/#{paint.to_param}", params: {paint: paint_attributes}
      paint.reload
      expect(paint.name).to eq "avacado sunset anthracite"
      expect(paint.color).to eq green
      expect(paint.secondary_color).to eq yellow
      expect(paint.tertiary_color).to eq gray
      bike.reload
      expect(bike.paint).to eq paint
      expect(bike.primary_frame_color).to eq green
      expect(bike.secondary_frame_color).to eq yellow
      expect(bike.tertiary_frame_color).to eq gray
    end
  end
end
