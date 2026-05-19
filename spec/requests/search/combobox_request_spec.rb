require "rails_helper"

RSpec.describe Search::ComboboxController, type: :request do
  describe "options" do
    let!(:color) { FactoryBot.create(:color, name: "Burgundy", display: "#900") }
    before { Autocomplete::Loader.load_all(%w[Color]) }

    it "renders matching autocomplete options" do
      get "/search/combobox/options", params: {q: "burg", for_id: "test"}, as: :turbo_stream

      expect(response.code).to eq("200")
      expect(response.body).to match(/hw-combobox__option/)
      expect(response.body).to include("Burgundy")
      expect(response.body).to include(color.search_id)
    end

    context "with a search_obj_name" do
      it "uses it in the option content" do
        get "/search/combobox/options",
          params: {q: "burg", for_id: "test", search_obj_name: "Listings"}, as: :turbo_stream

        expect(response.code).to eq("200")
        expect(response.body).to include("Listings that are")
      end
    end

    context "without matches" do
      it "renders an empty listbox" do
        get "/search/combobox/options", params: {q: "nonesuch", for_id: "test"}, as: :turbo_stream

        expect(response.code).to eq("200")
        expect(response.body).to_not match(/hw-combobox__option/)
      end
    end
  end

  describe "chips" do
    let!(:color) { FactoryBot.create(:color, name: "Burgundy") }
    let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Cool Bikes") }

    it "renders selection chips for the passed values" do
      values = [color.search_id, manufacturer.search_id, "free text"].join(",")
      post "/search/combobox/chips", params: {combobox_values: values, for_id: "test"}, as: :turbo_stream

      expect(response.code).to eq("200")
      expect(response.body).to include("Burgundy")
      expect(response.body).to include("Cool Bikes")
      expect(response.body).to include("free text")
      expect(response.body).to include(color.search_id)
    end

    context "with blank values" do
      it "renders nothing" do
        post "/search/combobox/chips", params: {combobox_values: "", for_id: "test"}, as: :turbo_stream

        expect(response.code).to eq("200")
        expect(response.body).to_not match(/hw-combobox__chip/)
      end
    end
  end
end
