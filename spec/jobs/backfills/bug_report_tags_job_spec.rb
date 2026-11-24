require "rails_helper"

RSpec.describe Backfills::BugReportTagsJob, type: :job do
  describe "perform" do
    let!(:organization_reply) { FactoryBot.create(:bug_report, tags: %w[auto_replies_organization]) }
    let!(:both) { FactoryBot.create(:bug_report, tags: %w[auto_replies auto_replies_organization search]) }
    let!(:other) { FactoryBot.create(:bug_report, tags: %w[spam]) }
    let(:feedback) { FactoryBot.create(:feedback, email: "Sender@Example.com", title: "Found Bike") }
    let(:body) { %(<a href="https://bikeindex.org/admin/feedbacks/#{feedback.id}">read full message</a>) }
    let!(:notification) { FactoryBot.create(:bug_report, email: "sender@example.com", subject: "Found Bike", body:, tags: %w[ask_found_bike]) }
    let!(:reply) { FactoryBot.create(:bug_report, email: "staff@bikeindex.org", subject: "Re: Found Bike", body:) }
    let!(:recovery) do
      FactoryBot.create(:bug_report, subject: "Stolen Bike Recovered!", tags: %w[area_stolen_flow ask_stolen_bike feedback parking],
        status: :investigate_priority_low)
    end
    let!(:resolved) { FactoryBot.create(:bug_report, subject: "Stolen Bike Recovered!", tags: %w[bug feedback], status: :resolved) }
    let!(:written) { FactoryBot.create(:bug_report, subject: "Stolen bike recovery", tags: %w[ask_stolen_bike], status: :investigate_priority_low) }

    it "replaces the organization tag, tags feedback notifications and retags by subject" do
      described_class.new.perform

      expect(organization_reply.reload.tags).to eq %w[auto_replies]
      expect(both.reload.tags).to eq %w[auto_replies search]
      expect(other.reload.tags).to eq %w[spam]
      expect(notification.reload.tags).to eq %w[ask_found_bike feedback]
      expect(reply.reload.tags).to eq []
      expect(recovery.reload).to have_attributes(tags: %w[bike_index_notification feedback parking], status: "ignored")
      expect(resolved.reload).to have_attributes(tags: %w[bike_index_notification feedback], status: "resolved")
      expect(written.reload).to have_attributes(tags: %w[ask_stolen_bike], status: "investigate_priority_low")
    end
  end
end
