require "rails_helper"

RSpec.describe LogSearcher do
  let(:log_path) { Rails.root.join("spec", "fixtures", "example_log.log") }

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
        result = described_class.rgrep_command(time, log_path: log_path).split(" | rg")

        expect(result.first).to eq target
        expect(result.last).to match time_target
      end
    end
  end

  describe "matching_search_lines" do
    it "returns lines" do
      # pp described_class.matching_search_lines
    end
  end

  describe "test adding log_lines" do
    xit "adds the lines" do
      pp described_class.log_lines_in_redis
      log_lines = described_class.rgrep_command("Admin::BikesController#index")
      described_class.write_log_lines(log_lines)
    end
  end
end
