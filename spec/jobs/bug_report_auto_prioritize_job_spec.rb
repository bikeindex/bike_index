# frozen_string_literal: true

require "rails_helper"

RSpec.describe BugReportAutoPrioritizeJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:bug_report) { FactoryBot.create(:bug_report) }

    it "sets the status to investigate_priority_low and adds no tags" do
      expect(bug_report.status).to eq "unprioritized"
      expect { instance.perform(bug_report.id) }.to change { bug_report.reload.status }
        .to("investigate_priority_low")
      expect(bug_report.tags).to eq([])
    end

    context "with an internal notification subject" do
      ["Bike Recovery", "Bike recovered", "Recovered Bike", "Stolen notification blocked!",
        "Marketplace message blocked!", "Cool Bike Shop doesn't have any admins!",
        "Organization wants to be shown", "Organization deleted themselves"].each do |subject|
        context "subject '#{subject}'" do
          let(:bug_report) { FactoryBot.create(:bug_report, subject:) }

          it "tags it bike_index_notification and ignores it" do
            instance.perform(bug_report.id)
            expect(bug_report.reload.tags).to eq(["bike_index_notification"])
            expect(bug_report.status).to eq("ignored")
          end
        end
      end
    end

    context "with an automatic reply subject" do
      ["Automatic reply: Stolen Bike Hot Sheet", "Out of Office", "auto-reply"].each do |subject|
        context "subject '#{subject}'" do
          let(:bug_report) { FactoryBot.create(:bug_report, subject:) }

          it "tags it auto_replies and ignores it" do
            instance.perform(bug_report.id)
            expect(bug_report.reload.tags).to eq(["auto_replies"])
            expect(bug_report.status).to eq("ignored")
          end
        end
      end
    end

    context "with a look-alike subject that isn't automated" do
      ["Recovered Bike investigation", "bike co-op, bike recovery?", "Cannot create an account",
        "Cannot leave organization"].each do |subject|
        context "subject '#{subject}'" do
          let(:bug_report) { FactoryBot.create(:bug_report, subject:) }

          it "does not tag it and prioritizes it low" do
            instance.perform(bug_report.id)
            expect(bug_report.reload.tags).to eq([])
            expect(bug_report.status).to eq("investigate_priority_low")
          end
        end
      end
    end

    context "from an organization auto-reply sender" do
      let(:bug_report) { FactoryBot.create(:bug_report, email: "helpdesk@example.edu", subject: "TICKET has been created") }

      context "when the sender list is empty" do
        before { stub_const("BugReportAutoPrioritizeJob::ORGANIZATION_AUTO_REPLY_SENDERS", []) }

        it "does not tag it" do
          instance.perform(bug_report.id)
          expect(bug_report.reload.tags).to eq([])
          expect(bug_report.status).to eq("investigate_priority_low")
        end
      end

      context "with a configured sender list" do
        before { stub_const("BugReportAutoPrioritizeJob::ORGANIZATION_AUTO_REPLY_SENDERS", %w[helpdesk@example.edu tickets.example.org]) }

        it "tags a configured email and ignores it" do
          instance.perform(bug_report.id)
          expect(bug_report.reload.tags).to eq(["auto_replies_organization"])
          expect(bug_report.status).to eq("ignored")
        end

        it "tags a configured domain but not other senders" do
          bug_report.update_column(:email, "noreply@tickets.example.org")
          instance.perform(bug_report.id)
          expect(bug_report.reload.tags).to eq(["auto_replies_organization"])

          other = FactoryBot.create(:bug_report, email: "someone@unlisted.example")
          instance.perform(other.id)
          expect(other.reload.tags).to eq([])
        end

        it "tags a subdomain of a configured domain" do
          bug_report.update_column(:email, "noreply@mail.tickets.example.org")
          instance.perform(bug_report.id)
          expect(bug_report.reload.tags).to eq(["auto_replies_organization"])
        end

        it "does not match a domain that merely ends with the configured one" do
          bug_report.update_column(:email, "noreply@nottickets.example.org")
          instance.perform(bug_report.id)
          expect(bug_report.reload.tags).to eq([])
        end

        # A From header without "@" parses through the mailbox as-is
        it "does not match a sender missing an @" do
          bug_report.update_column(:email, "tickets.example.org")
          instance.perform(bug_report.id)
          expect(bug_report.reload.tags).to eq([])
        end
      end
    end

    context "with a marketing HTML body" do
      # Marketing blasts arrive as HTML-only, which the estimator scores as spam
      let(:html_body) { '<!doctype html><html xmlns="http://www.w3.org/1999/xhtml"><head><meta charset="utf-8"><title></title></head><body><a href="https://t.co/x?utm=1">' }
      let(:bug_report) { FactoryBot.create(:bug_report, body: html_body) }

      it "tags it spam and ignores it" do
        expect(SpamEstimator::BugReport.estimate(bug_report))
          .to be > SpamEstimator::BugReport::MARK_SPAM_PERCENT
        instance.perform(bug_report.id)
        expect(bug_report.reload.tags).to eq(["spam"])
        expect(bug_report.status).to eq("ignored")
      end

      context "when it is also an auto-reply" do
        let(:bug_report) { FactoryBot.create(:bug_report, subject: "Automatic reply: out today", body: html_body) }

        it "tags it auto_replies but not spam" do
          instance.perform(bug_report.id)
          expect(bug_report.reload.tags).to eq(["auto_replies"])
          expect(bug_report.status).to eq("ignored")
        end
      end
    end

    context "when already prioritized" do
      let(:bug_report) { FactoryBot.create(:bug_report, subject: "Bike Recovery", status: :resolved) }

      it "still tags it but does not override the status" do
        instance.perform(bug_report.id)
        expect(bug_report.reload.tags).to eq(["bike_index_notification"])
        expect(bug_report.status).to eq("resolved")
      end
    end

    context "when the bug report does not exist" do
      it "does nothing" do
        expect { instance.perform(0) }.not_to raise_error
      end
    end
  end
end
