require "rails_helper"

RSpec.describe LogSearcher::Reader do
  let(:log_path) { Rails.root.join("spec", "fixtures", "example_log.log") }
  let(:redis) { Redis.new }

  describe "SEARCHES_MATCHES" do
    it "returns search strings" do
      expect(LogSearcher::Reader::SEARCHES_MATCHES.count).to be > 5
      expect(LogSearcher::Reader.searches_regex.split("|").count).to be > 3
    end
  end

  describe "rgrep_command" do
    let(:target) { "rg '#{described_class.searches_regex}' '#{log_path}' | sort -u" }
    it "returns a single rgrep" do
      expect(described_class.rgrep_command_str(log_path:)).to eq target
    end
    context "passed a time" do
      let(:time) { Time.at(1698092443) } # 2023-10-23 15:20
      let(:time_target) { "2023-10-23T20" }
      it "returns rgrep piped to a time regex" do
        expect(described_class.send(:time_rgrep, time)).to match time_target
        result = described_class.rgrep_command_str(time, log_path:)

        splitted = result.split(" | rg")
        expect(splitted.first).to eq target.gsub(" | sort -u", "")
        expect(splitted.last).to match time_target
      end
    end
  end

  describe "rgrep_log_lines_count" do
    let(:total_lines) { File.foreach(log_path).count }
    it "returns the expected log line count" do
      # When new lines are added to the example log file, this will fail.
      # Added as a failsafe because Seth didn't update the Reader when he updated the Parser in 2025-4
      # ... and didn't store web searches for ~ 2 months because of that
      expect(total_lines).to eq 31
      expect(LogSearcher::Reader.rgrep_log_lines_count(log_path:)).to eq 21
    end
  end

  describe "test adding log_lines" do
    let(:time) { Time.at(1698020443) } # 2023-10-22 17:20
    it "adds the lines" do
      redis.expire(described_class::KEY, 0)
      expect(described_class.log_lines_in_redis).to eq 0
      expect(described_class.rgrep_log_lines_count(time, log_path:)).to eq 3
      # Also, test that passing the command works
      command_str = described_class.rgrep_command_str(time, log_path:)
      expect(described_class.rgrep_log_lines_count(rgrep_command: command_str)).to eq 3
      described_class.write_log_lines(time, log_path:)
      expect(described_class.log_lines_in_redis).to eq 3
      # Clean up!
      redis.expire(described_class::KEY, 0)
    end
  end
end
