require "rails_helper"

RSpec.describe LogSearcher do
  describe "SEARCH_STRINGS" do
    it "returns search strings" do
      expect(LogSearcher::SEARCHES_MATCHES.count).to be > 5
      expect(LogSearcher.searches_regex).to match("BikesController#index|")
      expect(LogSearcher.searches_regex.split("|").count).to be > 3
    end
  end

  describe "rgrep_commands" do
    it "returns commands" do
      total_lines = 0
      LogSearcher::UNOVERLAP.each do |comm|
        lines = described_class.rgrep_command_log_lines(comm)
        pp "#{comm}  - #{lines}"
        total_lines += lines
      end
      pp total_lines
      pp described_class.rgrep_command_log_lines(LogSearcher::UNOVERLAP.join("|"))
      # grep "Admin::BikesController#index" ../testlog.log
    end
    # total_lines => 117,242
    context "regex version" do
      it "returns command" do
        joined_command = described_class.rgrep_commands.join("|")
        pp joined_command
        pp described_class.rgrep_command_log_lines(joined_command)
      end
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
