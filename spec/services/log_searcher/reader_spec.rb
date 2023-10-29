require "rails_helper"

RSpec.describe LogSearcher::Reader do
  let(:log_path) { Rails.root.join("spec", "fixtures", "example_log.log") }
  let(:redis) { Redis.new }

  describe "SEARCHES_MATCHES" do
    it "returns search strings" do
      expect(LogSearcher::Reader::SEARCHES_MATCHES.count).to be > 5
      expect(LogSearcher::Reader.searches_regex).to match("BikesController#index|")
      expect(LogSearcher::Reader.searches_regex.split("|").count).to be > 3
    end
  end

  describe "rgrep_command" do
    let(:target) { "rg '#{described_class.searches_regex}' '#{log_path}'" }
    it "returns a single rgrep" do
      expect(described_class.rgrep_command_str(log_path: log_path)).to eq target
    end
    context "passed a time" do
      let(:time) { Time.at(1698092443) } # 2023-10-23 15:20
      let(:time_target) { "2023-10-23T20" }
      it "returns rgrep piped to a time regex" do
        expect(described_class.send(:time_rgrep, time)).to match time_target
        result = described_class.rgrep_command_str(time, log_path: log_path)

        splitted = result.split(" | rg")
        expect(splitted.first).to eq target
        expect(splitted.last).to match time_target
      end
    end
  end

  describe "test adding log_lines" do
    let(:time) { Time.at(1698020443) }
    it "adds the lines" do
      redis.expire(LogSearcher::Reader::KEY, 0)
      expect(LogSearcher::Reader.log_lines_in_redis).to eq 0
      expect(LogSearcher::Reader.rgrep_log_lines_count(time, log_path: log_path)).to eq 3
      # Also, test that passing the command works
      command_str = LogSearcher::Reader.rgrep_command_str(time, log_path: log_path)
      expect(LogSearcher::Reader.rgrep_log_lines_count(rgrep_command: command_str)).to eq 3
      LogSearcher::Reader.write_log_lines(time, log_path: log_path)
      expect(LogSearcher::Reader.log_lines_in_redis).to eq 3
      # Clean up!
      redis.expire(LogSearcher::Reader::KEY, 0)
    end
  end
end
