# frozen_string_literal: true

require "rails_helper"

RSpec.describe BugReportJobs::AutoPrioritizeJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:bug_report) { FactoryBot.create(:bug_report) }

    it "sets the status to investigate_priority_low" do
      expect(bug_report.status).to eq "unprioritized"
      expect { instance.perform(bug_report.id) }.to change { bug_report.reload.status }
        .to("investigate_priority_low")
    end

    context "when already prioritized" do
      let(:bug_report) { FactoryBot.create(:bug_report, status: :resolved) }

      it "does not override the status" do
        expect { instance.perform(bug_report.id) }.not_to change { bug_report.reload.status }
      end
    end

    context "when the bug report does not exist" do
      it "does nothing" do
        expect { instance.perform(0) }.not_to raise_error
      end
    end
  end
end
