require "rails_helper"

RSpec.describe LogSearcher::Parser do
  describe "parse_log_line" do
    let(:log_line) do
      "I, [2023-10-23T00:20:01.681937 #6669]  INFO -- : [6473c6f5-51f6-422b-bb3c-7e94b670f520] " \
      "{\"method\":\"GET\",\"path\":\"/bikes\",\"format\":\"html\"," \
      "\"controller\":\"BikesController\",\"action\":\"index\",\"status\":200," \
      "\"duration\":1001.79,\"view\":52.68,\"db\":946.26,\"remote_ip\":\"11.222.33.4\"," \
      "\"u_id\":null,\"params\":{\"page\": 2},\"@timestamp\":\"2023-10-23T00:20:01.681Z\"," \
      "\"@version\":\"1\",\"message\":\"[200] GET /bikes (BikesController#index)\"}"
    end
    let(:time) { Time.parse("2023-10-23T00:20:01.681937 UTC") }
    let(:target) do
      {request_at: time, request_id: "6473c6f5-51f6-422b-bb3c-7e94b670f520",
       duration_ms: 1002, user_id: nil, organization_id: nil, endpoint: :web_bikes,
       ip_address: "11.222.33.4", query_items: {}, page: 2, serial_normalized: nil,
       stolenness: :all, includes_query: false}
    end
    it "parses into attrs" do
      # request_time actually takes line_data (not log_line) - but, it works either way
      expect(described_class.send(:parse_request_time, log_line)).to eq time
      expect(described_class.parse_log_line(log_line)).to match_hash_indifferently target
    end
    context "API" do
      let(:log_line) { 'I, [2023-10-23T00:20:29.448035 #666684]  INFO -- : [8f46986c-7d36-46f5-aeb6-9d4851de15b7] {"status":200,"method":"GET","path":"/api/v3/search/serials_containing","params":{"serial":"WCo2001xxxxx","serial_no_space":"WC02001XXXXX","raw_serial":"WC02001XXXXX","stolenness":"proximity","location":"you"},"host":"bikeindex.org","remote_ip":"11.222.33.4","u_id":1321,"format":"json","db":1879.08,"view":12.02999999999997,"duration":1891.11}' }
      let(:target) do
        {
          request_at: Time.at(1698020429).utc,
          request_id: "8f46986c-7d36-46f5-aeb6-9d4851de15b7",
          duration_ms: 1891,
          user_id: 1321,
          organization_id: nil,
          endpoint: :api_v3_serials_containing,
          ip_address: "11.222.33.4",
          query_items: {"serial" => "WCo2001xxxxx", "serial_no_space" => "WC02001XXXXX", "raw_serial" => "WC02001XXXXX", "stolenness" => "proximity", "location" => "you"},
          stolenness: :stolen,
          serial_normalized: "WC02001XXXXX",
          page: nil,
          includes_query: true
        }
      end
      it "parses" do
        expect(described_class.parse_log_line(log_line)).to match_hash_indifferently target
      end
    end
    context "organized" do
      let(:log_line) { 'I, [2023-10-23T17:57:36.142389 #666692]  INFO -- : [2ac7efc6-6660-4b11-a1ca-a276698bdbdf] {"method":"GET","path":"/o/hogwarts/bikes","format":"html","controller":"Organized::BikesController","action":"index","status":200,"allocations":510947,"duration":699.31,"view":307.43,"db":383.28,"remote_ip":"127.0.0.1","u_id":85,"params":{"page":"undefined","search_email":"","serial":"","sort":"id","sort_direction":"desc","render_chart":"false","period":"","end_time":"","start_time":"","user_id":"","search_bike_id":"","search_status":"","search_kind":"","organization_id":"hogwarts","stolenness":"stolen","search_stickers":"","search_address":"","search_secondary":[""]},"@timestamp":"2023-10-23T17:57:36.142Z","@version":"1","message":"[200] GET /o/hogwarts/bikes (Organized::BikesController#index)"}' }
      let!(:organization) { FactoryBot.create(:organization, name: "Hogwarts") }
      let(:target) do
        {
          request_at: Time.at(1698083856).utc,
          request_id: "2ac7efc6-6660-4b11-a1ca-a276698bdbdf",
          duration_ms: 699,
          user_id: 85,
          organization_id: organization.id,
          endpoint: :org_bikes,
          query_items: {sort: "id", sort_direction: "desc", render_chart: "false", stolenness: "stolen", organization_id: organization.slug},
          ip_address: "127.0.0.1",
          stolenness: :stolen,
          serial_normalized: nil,
          page: nil,
          includes_query: false
        }
      end
      it "parses" do
        expect(described_class.parse_log_line(log_line)).to match_hash_indifferently target
      end
      context "/v3/bikes/check_if_registered" do
        let(:log_line) { 'I, [2023-10-23T00:20:31.0000 #149741]  INFO -- : [7e0645ff-032e-4095-9a75-81afb12b8892] {"status":201,"method":"POST","path":"/api/v3/bikes/check_if_registered","params":{"access_token":"[FILTERED]","serial":"999xxxx","owner_email":"example@bikeindex.org","organization_slug":"hogwarts","manufacturer":"salsa"},"host":"bikeindex.org","remote_ip":"11.222.33.4","format":"json","db":1076.85,"view":15.86000000000013,"duration":1092.71}' }
        let(:target) do
          {
            request_at: Time.at(1698020431).utc,
            request_id: "7e0645ff-032e-4095-9a75-81afb12b8892",
            duration_ms: 1093,
            user_id: nil,
            organization_id: organization.id,
            endpoint: :api_v3_check_if_registered,
            ip_address: "11.222.33.4",
            query_items: {"serial" => "999xxxx", "manufacturer" => "salsa", "owner_email" => "example@bikeindex.org", :organization_slug => organization.slug},
            stolenness: :all,
            serial_normalized: "999XXXX",
            page: nil,
            includes_query: true
          }
        end
        it "parses" do
          expect(described_class.parse_log_line(log_line)).to match_hash_indifferently target
        end
      end
    end
    context "multiple data" do
      # Code doesn't handle this, so catch it
      let(:log_line) { "I, [2023-10-23T00:20:01.681937 #6669]  INFO -- : [6473c6f5-51f6-422b-bb3c-7e94b670f520] {\"params\": \"7e94b670f520] {\"}" }
      it "raises" do
        expect {
          described_class.parse_log_line(log_line)
        }.to raise_error(/multiple/i)
      end
    end
  end

  describe "example log" do
    let(:log_path) { Rails.root.join("spec", "fixtures", "example_log.log") }
    it "parses all the lines from the example" do
      log_lines = File.read(log_path).split("\n")
      expect(log_lines.count).to be > 15
      parsed_log_lines = log_lines.map { |l| described_class.parse_log_line(l) }.compact
      expect(parsed_log_lines.count).to be < log_lines.count
      # It should have every endpoint
      logged_endpoints = parsed_log_lines.map { |l| l[:endpoint] }.uniq.sort
      expect(LoggedSearch.endpoints_sym - logged_endpoints).to eq([])
      expect(logged_endpoints).to eq LoggedSearch.endpoints_sym.sort
    end
  end
end
