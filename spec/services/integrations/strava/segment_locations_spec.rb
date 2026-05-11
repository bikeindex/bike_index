# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Strava::SegmentLocations do
  let(:segment_effort_json) do
    '{"id":3098415184501105490,"resource_state":2,"name":"South Park - steep section","activity":{"id":9166353937,"visibility":"everyone","resource_state":1},"athlete":{"id":2430215,"resource_state":1},"elapsed_time":246,"moving_time":246,"start_date":"2023-05-29T22:22:08Z","start_date_local":"2023-05-29T15:22:08Z","distance":667.88,"start_index":8468,"end_index":8712,"device_watts":false,"average_heartrate":132.4,"max_heartrate":154.0,"segment":{"id":1287957,"resource_state":2,"name":"South Park - steep section","activity_type":"Ride","distance":667.88,"average_grade":8.6,"maximum_grade":21.3,"elevation_high":360.0,"elevation_low":302.8,"start_latlng":[37.89035322144628,-122.2365182172507],"end_latlng":[37.88604165427387,-122.2314907517284],"elevation_profile":null,"elevation_profiles":null,"climb_category":0,"city":"Orinda","state":"CA","country":"United States","private":false,"hazardous":false,"starred":false},"pr_rank":null,"achievements":[],"visibility":"everyone","kom_rank":null,"hidden":false}'
  end
  let(:orinda_target) do
    {locations: [{city: "Orinda", region: "CA", country: "US"}],
     regions: {"California" => "CA"},
     countries: {"United States" => "US"}}
  end

  describe "locations_for" do
    let(:segment_effort) { JSON.parse(segment_effort_json) }

    it "returns empty hash for blank segments" do
      expect(described_class.locations_for([])).to eq({})
      expect(described_class.locations_for(nil)).to eq({})
    end

    context "with a segment" do
      let!(:state) { FactoryBot.create(:state_california) }

      it "returns locations, regions, and countries" do
        result = described_class.locations_for([segment_effort])
        expect(result[:locations]).to eq(orinda_target[:locations])
        expect(result[:regions]).to eq(orinda_target[:regions])
        expect(result[:countries]).to eq(orinda_target[:countries])

        expect(result).to eq orinda_target
      end
    end

    context "kenya" do
      let!(:country) { FactoryBot.create(:country, name: "Kenya", iso: "KE") }
      # This is just a single segment, which doesn't have a city
      let(:segment_effort_json) { '{"id":3173383414465542036,"resource_state":2,"name":"to elsa we go 🦏","activity":{"id":584057489,"visibility":"everyone","resource_state":1},"athlete":{"id":2430215,"resource_state":1},"elapsed_time":979,"moving_time":840,"start_date":"2016-05-21T14:43:43Z","start_date_local":"2016-05-21T17:43:43Z","distance":3115.3,"start_index":195,"end_index":256,"device_watts":false,"segment":{"id":36019146,"resource_state":2,"name":"to elsa we go 🦏","activity_type":"Ride","distance":3115.3,"average_grade":0.1,"maximum_grade":0.8,"elevation_high":1915.9,"elevation_low":1901.7,"start_latlng":[-0.838308,36.35891],"end_latlng":[-0.826893,36.334255],"elevation_profile":null,"elevation_profiles":null,"climb_category":0,"city":null,"state":"Nakuru","country":"Kenya","private":false,"hazardous":false,"starred":false},"pr_rank":null,"achievements":[],"visibility":"everyone","kom_rank":null,"hidden":false}' }
      let(:target) do
        {locations: [{region: "Nakuru", country: "KE"}],
         countries: {"Kenya" => "KE"}}
      end

      it "returns correctly" do
        expect(described_class.locations_for([segment_effort])).to eq target
      end
    end

    context "null" do
      let(:segment_effort_json) { '{"id":3378804382000174786,"resource_state":2,"name":"Edgewood - 2am","activity":{"id":15081069773,"visibility":"everyone","resource_state":1},"athlete":{"id":2430215,"resource_state":1},"elapsed_time":184,"moving_time":184,"start_date":"2025-07-11T15:52:44Z","start_date_local":"2025-07-11T08:52:44Z","distance":2017.4,"start_index":11824,"end_index":12008,"device_watts":false,"average_heartrate":91.5,"max_heartrate":104.0,"segment":{"id":14475218,"resource_state":2,"name":"Edgewood - 2am","activity_type":"Ride","distance":2017.4,"average_grade":-7.4,"maximum_grade":0.7,"elevation_high":142.8,"elevation_low":-6.6,"start_latlng":[37.902509,-122.556788],"end_latlng":[37.896478,-122.538134],"elevation_profile":null,"elevation_profiles":null,"climb_category":0,"city":null,"state":null,"country":null,"private":false,"hazardous":false,"starred":false},"pr_rank":1,"achievements":[{"type_id":3,"type":"pr","rank":1}],"visibility":"everyone","kom_rank":null,"hidden":false}' }
      it "returns null" do
        expect(described_class.locations_for([segment_effort])).to eq({locations: []})
      end
    end
  end

  describe "segment_locations" do
    let(:segment) { JSON.parse(segment_effort_json)["segment"] }

    context "with state" do
      let!(:state) { FactoryBot.create(:state_california) }

      it "returns the location" do
        expect(described_class.send(:segment_location, segment, "CA", "US")).to eq orinda_target[:locations].first
      end

      context "with contra costa county location" do
        let(:segment_effort_json) do
          '{"id":3098415184501997394,"resource_state":2,"name":"South Park Episode 1","activity":{"id":9166353937,"visibility":"everyone","resource_state":1},"athlete":{"id":2430215,"resource_state":1},"elapsed_time":398,"moving_time":395,"start_date":"2023-05-29T22:18:55Z","start_date_local":"2023-05-29T15:18:55Z","distance":1130.1,"start_index":8276,"end_index":8671,"device_watts":false,"average_heartrate":135.8,"max_heartrate":156.0,"segment":{"id":7505681,"resource_state":2,"name":"South Park Episode 1","activity_type":"Ride","distance":1130.1,"average_grade":7.9,"maximum_grade":14.9,"elevation_high":381.5,"elevation_low":292.3,"start_latlng":[37.892246,-122.241988],"end_latlng":[37.886968,-122.232061],"elevation_profile":null,"elevation_profiles":null,"climb_category":1,"city":"Contra Costa County, CA, USA","state":"CA","country":"United States","private":false,"hazardous":false,"starred":false},"pr_rank":null,"achievements":[],"visibility":"everyone","kom_rank":null,"hidden":false}'
        end

        it "returns the location" do
          expect(described_class.send(:segment_location, segment, "CA", "US"))
            .to eq({city: "Contra Costa County", country: "US", region: "CA"})
        end
      end
    end
  end

  describe "find_country_abbreviation" do
    it "finds by StatesAndCountries self_name" do
      expect(described_class.send(:find_country_abbreviation, "España")).to eq({name: "Spain", abbreviation: "ES"})
    end

    it "finds by StatesAndCountries self_name" do
      expect(described_class.send(:find_country_abbreviation, "Slovenija")).to eq({name: "Slovenia", abbreviation: "SI"})
    end
  end
end
