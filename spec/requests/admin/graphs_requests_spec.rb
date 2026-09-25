require "rails_helper"

base_url = "/admin/graphs"
RSpec.describe Admin::GraphsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  describe "index" do
    context "graphs" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
    context "users" do
      it "renders" do
        get base_url, params: {search_kind: "users"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
    context "recoveries" do
      it "renders" do
        get base_url, params: {search_kind: "recoveries"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
    context "bikes" do
      it "renders" do
        get base_url, params: {search_kind: "bikes"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end

      context "with bikes registered different ways" do
        let!(:sticker_bikes) { FactoryBot.create_list(:bike, 2, :with_ownership, creation_state_origin: "sticker") }
        let!(:web_bike) { FactoryBot.create(:bike, :with_ownership, creation_state_origin: "web") }
        let(:origin_colors) { Pages::Admin::Graphs::Bikes::Component::ORIGIN_COLORS }
        # [origin, swatch color, bike count] per row of the origin table, as rendered
        let(:origin_rows) do
          Nokogiri::HTML(response.body).css("td span[style*='background-color']").map do |swatch|
            [swatch.next_sibling.text.strip, swatch["style"][/#\h{6}/], swatch.parent.next_element.text.strip]
          end
        end

        it "sorts the origin table highest count first, each swatch the chart's color for that origin" do
          get base_url, params: {search_kind: "bikes", period: "week"}
          expect(response.status).to eq(200)
          expect(origin_rows.first(2)).to eq([["Sticker", origin_colors["sticker"], "2"],
            ["Web", origin_colors["web"], "1"]])
          # The origins with no bikes keep Ownership.origins order, rather than reshuffling
          expect(origin_rows.map(&:first))
            .to eq(%w[sticker web].map(&:humanize) + (Ownership.origins - %w[sticker web]).map(&:humanize))

          get "#{base_url}/variable", params: {search_kind: "bikes", period: "week", bike_graph_kind: "origin"}
          expect(json_result.to_h { [it["name"], it["color"]] })
            .to eq(origin_colors.transform_keys(&:humanize))
          # Every origin gets a zero-filled series, not just the ones the grouped query found
          totals = json_result.to_h { |series| [series["name"], series["data"].sum(&:last)] }
          expect(totals).to eq(Ownership.origins.to_h { [it.humanize, 0] }.merge("Sticker" => 2, "Web" => 1))
        end
      end

      context "with bikes registered from the iOS app" do
        let!(:bikes_old_version) do
          FactoryBot.create_list(:bike, 2, :with_ownership, creation_registration_info: {ios_version: "1.6.9"})
        end
        let!(:bike_new_version) { FactoryBot.create(:bike, :with_ownership, creation_registration_info: {ios_version: "2.0.1"}) }
        let!(:web_bike) { FactoryBot.create(:bike, :with_ownership) }
        let(:ios_version_rows) do
          Nokogiri::HTML(response.body).css("tr").map { |row| row.css("td").map { it.text.strip } }
            .select { |cells| cells.first&.match?(/\A\d+\.\d+\.\d+\z/) }
        end

        it "counts bikes by iOS version, highest count first" do
          get base_url, params: {search_kind: "bikes", period: "week"}
          expect(response.status).to eq(200)
          expect(ios_version_rows).to eq([%w[1.6.9 2], %w[2.0.1 1]])

          get "#{base_url}/variable", params: {search_kind: "bikes", period: "week", bike_graph_kind: "ios_version"}
          expect(json_result.map { [it["name"], it["data"].sum(&:last)] })
            .to eq([["iOS 1.6.9", 2], ["iOS 2.0.1", 1]])
        end
      end
    end
  end

  describe "tables" do
    include_context :geocoder_default_location
    include_context :geocoder_stubbed_bounding_box
    it "renders" do
      get "#{base_url}/tables"
      expect(response.status).to eq(200)
      expect(response).to render_template(:tables)
      get "#{base_url}/tables", params: {location: "San Francisco, CA"}
      expect(response.status).to eq(200)
      expect(response).to render_template(:tables)
      expect(response.body).to include("within 100 miles of")
    end
  end

  describe "variable" do
    let(:earliest_time) { Time.at(1134972000) } # earliest_period_date
    it "returns json" do
      get "#{base_url}/variable"
      expect(response.status).to eq(200)
      expect(json_result["error"]).to be_present # Because kind is general, which doesn't get a graph
    end
    context "users" do
      it "returns json" do
        get "#{base_url}/variable", params: {search_kind: "users", timezone: "America/Los_Angeles", period: "all"}
        expect(response.status).to eq(200)
        expect(json_result.map { it["name"] }).to eq(["Users"])
        expect(assigns(:start_time)).to be_within(1.day).of earliest_time
        expect(assigns(:end_time)).to be_within(1.minute).of Time.current
      end

      context "passed date and time" do
        let(:end_time) { "2019-01-22T13:48" }
        let(:start_time) { "2019-01-15T14:48" }
        it "returns json" do
          get "#{base_url}/variable", params: {search_kind: "users", period: "custom", start_time: start_time, end_time: end_time, timezone: "America/Los_Angeles"}
          expect(response.status).to eq(200)
          expect(json_result.is_a?(Array)).to be_truthy
          Time.zone = Binxtils::TimeZoneParser.parse("America/Los_Angeles")
          expect(assigns(:start_time).strftime("%Y-%m-%dT%H:%M")).to eq start_time
          expect(assigns(:end_time).strftime("%Y-%m-%dT%H:%M")).to eq end_time
        end
      end
    end
    context "recoveries" do
      let!(:payment) { FactoryBot.create(:payment) }
      it "returns json" do
        get "#{base_url}/variable", params: {search_kind: "recoveries", timezone: "America/Los_Angeles"}
        expect(response.status).to eq(200)
        expect(json_result.map { it["name"] }).to eq(["Recoveries"])
        expect(assigns(:start_time)).to be_within(1.day).of(Time.current - 1.year)
        expect(assigns(:end_time)).to be_within(1.minute).of Time.current
      end
      context "passed date and time" do
        let(:end_time) { "2019-01-22T13:48" }
        let(:start_time) { "2019-01-15T14:48" }
        it "returns json" do
          get "#{base_url}/variable", params: {search_kind: "recoveries", period: "custom", start_time: start_time, end_time: end_time, timezone: "America/Los_Angeles"}
          expect(response.status).to eq(200)
          expect(json_result.is_a?(Array)).to be_truthy
          Time.zone = Binxtils::TimeZoneParser.parse("America/Los_Angeles")
          expect(assigns(:start_time).strftime("%Y-%m-%dT%H:%M")).to eq start_time
          expect(assigns(:end_time).strftime("%Y-%m-%dT%H:%M")).to eq end_time
        end
      end
    end
    context "bikes" do
      it "returns json" do
        get "#{base_url}/variable", params: {search_kind: "bikes", timezone: "America/Los_Angeles"}
        expect(response.status).to eq(200)
        expect(json_result.is_a?(Array)).to be_truthy
        expect(assigns(:start_time)).to be_within(1.day).of(Time.current - 1.year)
        expect(assigns(:end_time)).to be_within(1.minute).of Time.current
        # And it gets the other kinds too
        get "#{base_url}/variable", params: {search_kind: "bikes", timezone: "America/Los_Angeles", bike_graph_kind: "origin"}
        expect(json_result.is_a?(Array)).to be_truthy
        get "#{base_url}/variable", params: {search_kind: "bikes", timezone: "America/Los_Angeles", bike_graph_kind: "pos"}
        expect(json_result.is_a?(Array)).to be_truthy
      end
    end
  end
end
