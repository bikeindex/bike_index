require "rails_helper"

RSpec.describe LogSearcher do
  describe "SEARCHES_MATCHES" do
    it "returns search strings" do
      expect(LogSearcher::SEARCHES_MATCHES.count).to be > 5
      expect(LogSearcher.searches_regex).to match("BikesController#index|")
      expect(LogSearcher.searches_regex.split("|").count).to be > 3
    end
  end

  describe "test adding log_lines" do
    xit "adds the lines" do
      pp described_class.log_lines_in_redis
      log_lines = described_class.rgrep_command("Admin::BikesController#index")
      pp log_lines
      described_class.write_log_lines(log_lines)
      pp described_class.log_lines_in_redis
    end
  end
end
