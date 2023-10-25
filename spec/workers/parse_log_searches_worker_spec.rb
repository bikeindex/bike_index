require "rails_helper"

RSpec.describe ParseLogSearchesWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

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
