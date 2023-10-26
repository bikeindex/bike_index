require "rails_helper"

RSpec.describe LogSearcher::Reader do
  let(:log_path) { Rails.root.join("spec", "fixtures", "example_log.log") }
  let(:redis) { Redis.new }

  describe "SEARCHES_MATCHES" do
    it "returns search strings" do
      expect(LogSearcher::SEARCHES_MATCHES.count).to be > 5
      expect(LogSearcher.searches_regex).to match("BikesController#index|")
      expect(LogSearcher.searches_regex.split("|").count).to be > 3
    end
  end

  describe "rgrep_command" do
    let(:target) { "rg '#{described_class.searches_regex}' '#{log_path}'" }
    it "returns a single rgrep" do
      expect(described_class.rgrep_command(log_path: log_path)).to eq target
    end
    context "passed a time" do
      let(:time) { Time.at(1698092443) } # 2023-10-23 15:20
      let(:time_target) { "2023-10-23T20" }
      it "returns rgrep piped to a time regex" do
        expect(described_class.send(:time_rgrep, time)).to match time_target
        result = described_class.rgrep_command(time, log_path: log_path)

        splitted = result.split(" | rg")
        expect(splitted.first).to eq target
        expect(splitted.last).to match time_target
      end
    end
  end

  describe "test adding log_lines" do
    let(:time) { Time.at(1698020443) }
    it "adds the lines" do
      redis.expire(LogSearcher::KEY, 0)
      expect(LogSearcher.log_lines_in_redis).to eq 0
      LogSearcher.write_log_lines(LogSearcher.rgrep_command(time, log_path: log_path))
      sleep 1 if ENV["CI"] # Maybe fix CI?
      expect(LogSearcher.log_lines_in_redis).to eq 3
      redis.expire(LogSearcher::KEY, 0)
    end
  end

  describe "log_lines_array" do
    it "has every endpoint type"
  end

  describe "parse_log_line" do
    let(:log_line) do
      "I, [2023-10-23T00:20:01.681937 #6669]  INFO -- : [6473c6f5-51f6-422b-bb3c-7e94b670f520] " \
      "{\"method\":\"GET\",\"path\":\"/bikes\",\"format\":\"html\"," \
      "\"controller\":\"BikesController\",\"action\":\"index\",\"status\":200," \
      "\"duration\":1001.79,\"view\":52.68,\"db\":946.26,\"remote_ip\":\"11.222.33.4\"," \
      "\"u_id\":null,\"params\":{},\"@timestamp\":\"2023-10-23T00:20:01.681Z\"," \
      "\"@version\":\"1\",\"message\":\"[200] GET /bikes (BikesController#index)\"}"
    end
    let(:time) { Time.parse("2023-10-23T00:20:01.681937 UTC") }
    let(:target) do
      {request_at: time, request_id: "6473c6f5-51f6-422b-bb3c-7e94b670f520",
       duration_ms: 1002, user_id: nil, organization_id: nil, endpoint: :web,
       ip_address: "11.222.33.4", query_items: {}, page: nil}
    end
    it "parses into attrs" do
      # request_time actually takes line_data (not log_line) - but, it works either way
      expect(described_class.send(:parse_request_time, log_line)).to eq time
      expect_hashes_to_match(described_class.parse_log_line(log_line), target)
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
end
