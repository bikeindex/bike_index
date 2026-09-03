require "rails_helper"

RSpec.describe SpamEstimator::BugReport do
  describe "estimate" do
    it "is 0 for a blank bug report" do
      expect(described_class.estimate(nil)).to eq 0
    end

    context "a plain-text report" do
      let(:bug_report) { FactoryBot.build(:bug_report, subject: "Search is broken", body: "I searched for my bike and nothing happened, can you help?") }

      it "scores below the spam threshold" do
        expect(described_class.estimate(bug_report)).to be < described_class::MARK_SPAM_PERCENT
      end
    end

    context "an HTML marketing body" do
      let(:body) { '<!doctype html><html xmlns="http://www.w3.org/1999/xhtml"><head><meta charset="utf-8"><title></title></head><body><a href="https://t.co/x?utm=1">' }
      let(:bug_report) { FactoryBot.build(:bug_report, subject: "New seller? June is the best time to start", body:) }

      it "scores as spam" do
        expect(described_class.estimate(bug_report)).to be > described_class::MARK_SPAM_PERCENT
      end
    end

    context "a malicious subject" do
      let(:bug_report) { FactoryBot.build(:bug_report, subject: "<script>alert(1)</script>", body: "hi") }

      it "scores 100" do
        expect(described_class.estimate(bug_report)).to eq 100
      end
    end
  end
end
