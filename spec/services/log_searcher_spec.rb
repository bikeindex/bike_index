require "rails_helper"

RSpec.describe LogSearcher do
  describe "SEARCH_STRINGS" do
    it "returns search strings" do
      expect(LogSearcher::SEARCH_STRINGS.count).to be > 6
    end
  end

  describe "grep_commands" do
    it "returns commands" do
      described_class.grep_commands.each do |comm|
        pp "#{comm}  - #{described_class.grep_command_log_lines(comm)}"
      end
    end
  end
end
