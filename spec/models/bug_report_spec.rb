require "rails_helper"

RSpec.describe BugReport, type: :model do
  describe "factory" do
    it "is valid" do
      expect(FactoryBot.create(:bug_report)).to be_valid
    end
  end

  describe "display_subject" do
    it "falls back when blank" do
      expect(BugReport.new(subject: "").display_subject).to eq "(no subject)"
      expect(BugReport.new(subject: "Crash").display_subject).to eq "Crash"
    end
  end
end
