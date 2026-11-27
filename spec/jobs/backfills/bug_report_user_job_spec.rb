require "rails_helper"

RSpec.describe Backfills::BugReportUserJob, type: :job do
  describe "perform" do
    let!(:bug_report) { FactoryBot.create(:bug_report, email: "later@example.com") }
    let!(:unmatched) { FactoryBot.create(:bug_report, email: "nobody@example.com") }

    it "links reports to a confirmed account created after them" do
      user = FactoryBot.create(:user_confirmed, email: "later@example.com")
      FactoryBot.create(:user, email: "nobody@example.com")
      expect(bug_report.reload.user_id).to be_nil

      described_class.new.perform

      expect(bug_report.reload.user_id).to eq user.id
      expect(unmatched.reload.user_id).to be_nil
    end
  end
end
