require "rails_helper"

RSpec.describe Search::ComboboxController, type: :request do
  describe "options" do
    let!(:color) { FactoryBot.create(:color, name: "Burgundy", display: "#900") }
    before { Autocomplete::Loader.load_all(%w[Color]) }

    it "renders matching autocomplete options plus the 'Search for' synthetic" do
      get "/search/combobox/options", params: {q: "burg", for_id: "test"}, as: :turbo_stream

      expect(response.code).to eq("200")
      expect(response.body).to match(/hw-combobox__option/)
      expect(response.body).to include("Burgundy")
      expect(response.body).to include(color.search_id)
      expect(response.body).to include("Search for")
      expect(response.body).to include("hw_search_for_option")
    end

    context "with a search_obj_name" do
      it "uses it in the option content" do
        get "/search/combobox/options",
          params: {q: "burg", for_id: "test", search_obj_name: "Listings"}, as: :turbo_stream

        expect(response.code).to eq("200")
        expect(response.body).to include("Listings that are")
      end
    end

    context "without matching items" do
      it "still renders the 'Search for' synthetic option" do
        get "/search/combobox/options", params: {q: "nonesuch", for_id: "test"}, as: :turbo_stream

        expect(response.code).to eq("200")
        expect(response.body).to include("Search for")
        expect(response.body).to include("nonesuch")
      end
    end

    context "without a turbo_stream format (mangled pagination src)" do
      # A crawler following the HTML-encoded "&amp;format=turbo_stream" sends the
      # format param as "amp;format", so the request would default to :html and
      # raise ActionView::MissingTemplate for the turbo_stream-only gem partials.
      it "still renders the turbo_stream response" do
        get "/search/combobox/options", params: {q: "burg", for_id: "test"}

        expect(response.code).to eq("200")
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("Burgundy")
      end
    end

    context "with manufacturers of differing priority" do
      let!(:high) { FactoryBot.create(:manufacturer, name: "Acme Bikes") }
      let!(:low) { FactoryBot.create(:manufacturer, name: "Acme Components") }
      let!(:bike) { FactoryBot.create(:bike, manufacturer: high) }

      before do
        # bike creation doesn't trigger Manufacturer#before_save, so reload + update
        # to recompute calculated_priority with the new b_count
        Manufacturer.find(high.id).update(updated_at: Time.current)
        Autocomplete::Loader.load_all(%w[Manufacturer])
      end

      it "orders by Manufacturer#calculated_priority" do
        expect(Manufacturer.find(high.id).priority).to be > Manufacturer.find(low.id).priority

        get "/search/combobox/options", params: {q: "acme", for_id: "test"}, as: :turbo_stream

        expect(response.body.index("m_#{high.id}")).to be < response.body.index("m_#{low.id}")
      end
    end
  end

  describe "manufacturers" do
    let!(:trek) { FactoryBot.create(:manufacturer, name: "Trek", frame_maker: true) }
    let!(:trek_components) { FactoryBot.create(:manufacturer, name: "Trek Parts", frame_maker: false) }
    let!(:avantrek) { FactoryBot.create(:manufacturer, name: "AVANTREK", frame_maker: true) }
    # Matcher results are cached in redis for 10 minutes, which outlives the example
    before { Autocomplete::Loader.clear_redis && Autocomplete::Loader.load_all(%w[Manufacturer]) }

    it "renders the matching manufacturers, plus the unknown manufacturer synthetic" do
      get "/search/combobox/manufacturers", params: {q: "tre", for_id: "test"}, as: :turbo_stream

      expect(response.code).to eq("200")
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("data-value=\"#{trek.id}\"")
      expect(response.body).to include("data-value=\"#{trek_components.id}\"")
      # AVANTREK isn't a match - the autocomplete index matches on word prefixes
      expect(response.body).to_not include("data-value=\"#{avantrek.id}\"")
      # Manufacturer.other is never selectable
      expect(response.body).to_not include("data-value=\"#{Manufacturer.other.id}\"")
      expect(response.body).to include("Unknown manufacturer")
      expect(response.body).to include("hw_unknown_manufacturer_option")
      # Matches of equal priority are alphabetical
      expect(response.body.index("data-value=\"#{trek.id}\""))
        .to be < response.body.index("data-value=\"#{trek_components.id}\"")
    end

    context "with matches of differing priority" do
      let!(:bike) { FactoryBot.create(:bike, manufacturer: trek_components) }

      before do
        # bike creation doesn't trigger Manufacturer#before_save, so update to
        # recompute calculated_priority with the new b_count
        Manufacturer.find(trek_components.id).update(updated_at: Time.current)
        Autocomplete::Loader.load_all(%w[Manufacturer])
      end

      it "orders by priority" do
        expect(Manufacturer.find(trek_components.id).priority).to be > trek.reload.priority

        get "/search/combobox/manufacturers", params: {q: "tre", for_id: "test"}, as: :turbo_stream

        expect(response.body.index("data-value=\"#{trek_components.id}\""))
          .to be < response.body.index("data-value=\"#{trek.id}\"")
      end
    end

    context "with frame_maker" do
      it "only renders frame makers" do
        get "/search/combobox/manufacturers", params: {q: "tre", frame_maker: "true", for_id: "test"}, as: :turbo_stream

        expect(response.body).to include("data-value=\"#{trek.id}\"")
        expect(response.body).to_not include("data-value=\"#{trek_components.id}\"")
      end
    end

    context "with no_manufacturer_other" do
      it "doesn't render the unknown manufacturer synthetic" do
        get "/search/combobox/manufacturers",
          params: {q: "nonesuch", no_manufacturer_other: "true", for_id: "test"}, as: :turbo_stream

        expect(response.code).to eq("200")
        expect(response.body).to_not include("Unknown manufacturer")
      end
    end

    context "with an exact match" do
      it "doesn't render the unknown manufacturer synthetic" do
        get "/search/combobox/manufacturers", params: {q: "tre", for_id: "test"}, as: :turbo_stream
        expect(response.body).to include("hw_unknown_manufacturer_option")

        get "/search/combobox/manufacturers", params: {q: "Trek", for_id: "test"}, as: :turbo_stream
        expect(response.body).to_not include("hw_unknown_manufacturer_option")
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
      # Turbo drops any other content type, and the body looks the same either way
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
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

  describe "rack_attack" do
    include_context :rack_attack

    # The per-keystroke autocomplete is the heaviest search endpoint, so it rides
    # the generous API limit rather than the strict per-page request limit, which
    # active typing would otherwise trip.
    it "throttles at the API limit, not the lower per-page limit" do
      expect(Rack::Attack::API_MAX_REQUESTS).to be > Rack::Attack::MAX_REQUESTS_PER_TWENTY
      throttled = rack_attack_throttled_response(limit: Rack::Attack::API_MAX_REQUESTS) do
        get "/search/combobox/options", params: {q: "x", for_id: "test"}, as: :turbo_stream
        response
      end
      expect(throttled).to have_http_status(:too_many_requests)
    end
  end
end
