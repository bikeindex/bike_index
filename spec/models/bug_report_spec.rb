require "rails_helper"

RSpec.describe BugReport, type: :model do
  describe "set_calculated_attributes" do
    let(:bug_report) do
      FactoryBot.create(:bug_report, email: "SomeOne@example.com ",
        receiver: " Contact@bikeindex.org", tags: "Broken , search,broken,")
    end

    it "normalizes email, receiver and tags" do
      expect(bug_report).to have_attributes(email: "someone@example.com",
        receiver: "contact@bikeindex.org", tags: %w[broken search],
        user_id: nil, is_member: false,
        is_paid_organization: false, is_paid_organization_staff: false)
    end

    context "with a user" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      let(:bug_report) { FactoryBot.create(:bug_report, email: user.email) }

      it "associates the user" do
        expect(bug_report).to have_attributes(user_id: user.id, is_member: false,
          is_paid_organization: false, is_paid_organization_staff: false)
      end

      context "with an active membership" do
        let!(:membership) { FactoryBot.create(:membership, user:) }

        it "is_member" do
          expect(bug_report).to have_attributes(user_id: user.id, is_member: true,
            is_paid_organization: false, is_paid_organization_staff: false)
        end
      end

      context "when the user becomes a member after creation" do
        it "keeps the creation-time snapshot" do
          expect(bug_report.is_member).to be_falsey
          FactoryBot.create(:membership, user:)
          bug_report.update!(tags: ["search"])
          expect(bug_report.reload.is_member).to be_falsey
        end
      end

      context "in a paid organization" do
        let(:organization) { FactoryBot.create(:organization, :paid) }
        let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user:, organization:, role:) }
        let(:role) { "member" }

        it "is_paid_organization" do
          expect(bug_report).to have_attributes(user_id: user.id, is_member: false,
            is_paid_organization: true, is_paid_organization_staff: false)
        end

        context "with an admin role" do
          let(:role) { "admin" }

          it "is_paid_organization_staff" do
            expect(bug_report).to have_attributes(user_id: user.id, is_member: false,
              is_paid_organization: true, is_paid_organization_staff: true)
          end
        end
      end
    end
  end

  describe "versioning" do
    include_context :with_paper_trail

    let(:bug_report) { FactoryBot.create(:bug_report, tags: ["search"]) }

    it "creates versions for tracked attributes" do
      expect(bug_report.versions.count).to eq 1
      expect(bug_report.versions.last.event).to eq "create"

      bug_report.update!(tags: ["search", "broken"], github_pull_request: 3805)
      expect(bug_report.versions.count).to eq 2
      target_changes = {tags: [["search"], ["broken", "search"]], github_pull_request: [nil, 3805]}
      expect(bug_report.versions.last.object_changes).to eq target_changes.as_json

      # untracked attributes don't create versions
      bug_report.update!(subject: "A new subject")
      expect(bug_report.versions.count).to eq 2
    end
  end

  describe "with_tag and all_tags" do
    let!(:bug_report) { FactoryBot.create(:bug_report, tags: %w[search broken]) }
    let!(:bug_report_other) { FactoryBot.create(:bug_report, tags: ["search"]) }

    it "matches bug reports with the tag" do
      expect(BugReport.with_tag("broken").pluck(:id)).to eq([bug_report.id])
      expect(BugReport.with_tag("search").pluck(:id)).to match_array([bug_report.id, bug_report_other.id])
      expect(BugReport.all_tags).to eq(%w[broken search])
    end
  end

  describe "all_receivers" do
    let!(:bug_report) { FactoryBot.create(:bug_report, receiver: "support@bikeindex.org") }
    let!(:bug_report_other) { FactoryBot.create(:bug_report, receiver: "contact@bikeindex.org") }
    let!(:bug_report_without_receiver) { FactoryBot.create(:bug_report, receiver: nil) }

    it "returns the distinct receivers" do
      expect(BugReport.all_receivers).to eq(%w[contact@bikeindex.org support@bikeindex.org])
    end
  end

  describe "display_receiver" do
    it "drops our domain" do
      expect(BugReport.display_receiver("contact@bikeindex.org")).to eq "contact"
      expect(BugReport.display_receiver("someone@example.com")).to eq "someone@example.com"
      expect(BugReport.display_receiver(nil)).to eq ""
    end
  end

  describe "receiver_from_mail" do
    let(:mail) { Mail.new(from: "someone@example.com", to: "Bugs@bikeindex.org", subject: "Hi", body: "Hello") }

    it "normalizes the address it was sent to" do
      expect(BugReport.receiver_from_mail(mail)).to eq "bugs@bikeindex.org"
    end

    context "addressed to someone else too" do
      let(:mail) { Mail.new(from: "someone@example.com", to: ["friend@example.com", "contact@bikeindex.org"]) }

      it "prefers our address" do
        expect(BugReport.receiver_from_mail(mail)).to eq "contact@bikeindex.org"
      end
    end

    context "with our address cc'd" do
      let(:mail) { Mail.new(from: "someone@example.com", to: "friend@example.com", cc: "Support@bikeindex.org") }

      it "receives the cc" do
        expect(BugReport.receiver_from_mail(mail)).to eq "support@bikeindex.org"
      end
    end

    context "with an X-Original-To header" do
      let(:mail) do
        Mail.new(:from => "someone@example.com", :to => "friend@example.com",
          "X-Original-To" => "contact@bikeindex.org")
      end

      it "receives the envelope recipient" do
        expect(BugReport.receiver_from_mail(mail)).to eq "contact@bikeindex.org"
      end
    end

    context "forwarded to our postmark inbound address" do
      let(:mail) do
        Mail.new(from: "someone@example.com", to: "someone@example.com").tap do |mail|
          mail.header["X-Original-To"] = "b38985257f7d2266ccc3d152d0ecd32c@inbound.postmarkapp.com"
          mail.header["Received"] = "by mail-yw1-f197.google.com with SMTP id 007 " \
            "for <b38985257f7d2266ccc3d152d0ecd32c@inbound.postmarkapp.com>; Wed, 22 Jul 2026 15:19:03 +0000"
          mail.header["Received"] = "from YT5PR01CU002.outbound.protection.outlook.com by mx.google.com " \
            "with SMTPS id 5b1 for <Contact@bikeindex.org>; Wed, 22 Jul 2026 08:19:02 -0700"
        end
      end

      it "receives the address the forwarding hop accepted it for" do
        expect(BugReport.receiver_from_mail(mail)).to eq "contact@bikeindex.org"
      end
    end

    context "without an address of ours" do
      let(:mail) { Mail.new(from: "someone@example.com", to: "Friend@example.com") }

      it "is nil, rather than recording someone else's address" do
        expect(BugReport.receiver_from_mail(mail)).to be_nil
      end

      context "without any recipient" do
        let(:mail) { Mail.new(from: "someone@example.com") }

        it "is nil" do
          expect(BugReport.receiver_from_mail(mail)).to be_nil
        end
      end
    end
  end

  describe "github_pull_request_url" do
    let(:bug_report) { FactoryBot.build(:bug_report, github_pull_request: 3805) }

    it "returns the pull request url" do
      expect(bug_report.github_pull_request_url).to eq "https://github.com/bikeindex/bike_index/pull/3805"
      bug_report.github_pull_request = nil
      expect(bug_report.github_pull_request_url).to be_nil
    end
  end

  describe "display_subject" do
    let(:bug_report) { FactoryBot.build(:bug_report, subject: " ") }

    it "falls back when blank" do
      expect(bug_report.display_subject).to eq "(no subject)"
    end
  end

  describe "status_display" do
    it "abbreviates the investigate priorities" do
      expect(BugReport.status_display("unprioritized")).to eq "unprioritized"
      expect(BugReport.status_display("investigate_priority_high")).to eq "investigate p high"
      expect(BugReport.status_display("investigate_priority_low")).to eq "investigate p low"
      expect(BugReport.status_display(nil)).to be_nil
    end
  end

  describe "body_stripped" do
    let(:bug_report) { FactoryBot.build(:bug_report, body:) }
    let(:body) { "Hi & hello\n\nMy bike is gone" }

    it "keeps the line breaks and the ampersand" do
      expect(bug_report.body_stripped).to eq body
      expect(bug_report.body_significant_tags?).to be_falsey
    end

    context "with ragged whitespace" do
      let(:body) { "  Hi & hello\t\n   \n\n\n  My bike is gone  \n\n\n" }

      it "trims each line and collapses the blank runs to one" do
        expect(bug_report.body_stripped).to eq "Hi & hello\n\nMy bike is gone"
        expect(bug_report.body_significant_tags?).to be_falsey
      end
    end

    context "with an autolink" do
      let(:body) { "My bike <https://bikeindex.org/bikes/1> is gone.\n\n#{"Please help me find it. " * 20}" }

      it "drops it, but not significantly" do
        expect(bug_report.body_stripped).to start_with "My bike  is gone.\n\nPlease help"
        expect(bug_report.body_significant_tags?).to be_falsey
      end
    end

    context "with an html body" do
      let(:body) { "<html><body style=\"padding:0;margin:0\"><div><p>It&#39;s 5 &lt; 6 &amp; &quot;broken&quot;</p></div></body></html>" }

      it "is the text with the entities unescaped, and the tags are significant" do
        expect(bug_report.body_stripped).to eq "It's 5 < 6 & \"broken\""
        expect(bug_report.body_significant_tags?).to be_truthy
      end
    end

    context "without a body" do
      let(:body) { nil }

      it "is blank, without significant tags" do
        expect(bug_report.body_stripped).to eq ""
        expect(bug_report.body_significant_tags?).to be_falsey
      end
    end
  end

  describe "scopes" do
    let!(:paid_staff) { FactoryBot.create(:bug_report, is_paid_organization: true, is_paid_organization_staff: true, status: :resolved) }
    let!(:member) { FactoryBot.create(:bug_report, is_member: true, status: :investigate_priority_low) }

    it "filters by membership and investigate status" do
      expect(BugReport.member.pluck(:id)).to eq([member.id])
      expect(BugReport.paid_organization.pluck(:id)).to eq([paid_staff.id])
      expect(BugReport.paid_organization_staff.pluck(:id)).to eq([paid_staff.id])
      # investigate includes unprioritized, excludes resolved/ignored
      expect(BugReport.investigate.pluck(:id)).to eq([member.id])
    end
  end

  describe "ignored_tag?" do
    it "is true when a tag is in IGNORED_TAGS" do
      expect(FactoryBot.build(:bug_report, tags: ["bike_index_notification"]).ignored_tag?).to be true
      expect(FactoryBot.build(:bug_report, tags: %w[search broken]).ignored_tag?).to be false
    end
  end
end
