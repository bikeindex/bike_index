require "rails_helper"

RSpec.describe LogSearcher do
  describe "SEARCH_STRINGS" do
    it "returns search strings" do
      expect(LogSearcher::SEARCH_STRINGS.count).to be > 6
    end
  end

  # describe "grep_commands" do
  #   it "returns commands" do
  #     total_lines = 0
  #     described_class.grep_commands.each do |comm|
  #       lines = described_class.grep_command_log_lines(comm)
  #       pp "#{comm}  - #{lines}"
  #       total_lines += lines
  #     end
  #     pp total_lines
  #     # grep "Admin::BikesController#index" ../testlog.log
  #   end
  # end

  describe "test adding log_lines" do
    it "adds the lines" do
      pp described_class.log_lines_in_redis
      log_lines = described_class.grep_command("Admin::BikesController#index")
      pp log_lines
      described_class.write_log_lines(log_lines)
      pp described_class.log_lines_in_redis
    end
  end
end
