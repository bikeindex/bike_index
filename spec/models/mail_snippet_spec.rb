require "rails_helper"

RSpec.describe MailSnippet, type: :model do
  describe "disable_if_blank" do
    it "sets unenabled if body is blank" do
      mail_snippet = MailSnippet.new(is_enabled: true, body: nil, kind: "welcome")
      expect(mail_snippet.is_enabled).to be_truthy
      mail_snippet.save
      expect(mail_snippet.is_enabled).to be_falsey
      expect(mail_snippet.kind).to eq "welcome"
    end
  end

  describe "kinds" do
    it "includes all the ParkingNotification kinds" do
      expect(MailSnippet.kinds.count).to eq MailSnippet::KIND_ENUM.values.uniq.count
      expect((MailSnippet.kinds & ParkingNotification.kinds).count).to eq(ParkingNotification.kinds.count)
    end
  end

  describe "organization_emails_with_snippets" do
    let(:target) do
      %w[
        finished_registration
        finished_registration_stolen
        partial_registration
        appears_abandoned_notification
        parked_incorrectly_notification
        other_parking_notification
        impound_notification
        impound_claim_approved
        impound_claim_denied
        graduated_notification
      ]
    end
    it "is target" do
      # TODO - maybe better to use actual email methods?
      # all_emails = OrganizedMailer.new.methods - AdminMailer.new.methods
      expect(MailSnippet.organization_emails_with_snippets.sort).to eq target.sort
    end
  end

  describe "organization_snippets_in_all" do
    it "is the kinds in all" do
      expect(MailSnippet.organization_snippets_in_all).to match_array(%w[header footer])
    end
  end

  describe "organization_email" do
    let(:mail_snippet) { MailSnippet.new(kind: kind) }
    let(:kind) { "header" }
    it "is in all" do
      expect(MailSnippet.organization_email_for(:header)).to eq "all"
      expect(MailSnippet.organization_email_for("header")).to eq "all"
      expect(mail_snippet.which_organization_email).to eq "all"
      expect(mail_snippet.in_email?("finished_registration")).to be_truthy
      expect(mail_snippet.in_email?("finished_registration", exclude_all: true)).to be_falsey
      MailSnippet.organization_emails_with_snippets.each do |email|
        expect(mail_snippet.in_email?(email)).to be_truthy
      end
    end
    context "organization_message_kinds" do
      it "is kind" do
        MailSnippet.organization_message_kinds.each do |kind|
          message_mail_snippet = MailSnippet.new(kind: kind)
          expect(message_mail_snippet.which_organization_email).to eq kind
          expect(message_mail_snippet.in_email?(kind)).to be_truthy
          expect(message_mail_snippet.in_email?("finished_registration")).to be_falsey
        end
      end
    end
  end

  describe "for_organization" do
    include_context :with_paper_trail

    subject(:result) { MailSnippet.for_organization(organization_id:, kind:, time:) }

    let(:organization) { FactoryBot.create(:organization) }
    let(:organization_id) { organization.id }
    let(:kind) { "parked_incorrectly_notification" }
    let(:time) { nil }
    let(:body) { "current body" }
    let(:is_enabled) { true }
    let!(:mail_snippet) do
      FactoryBot.create(:mail_snippet, kind:, organization:, is_enabled:, body:)
    end

    context "without time" do
      it "returns the current snippet" do
        expect(result).to eq mail_snippet
      end
    end

    context "with unknown organization" do
      let(:organization_id) { organization.id + 999 }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "when currently disabled" do
      let(:is_enabled) { false }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with time after the snippet was edited" do
      let(:time) { 1.hour.ago }

      before do
        mail_snippet.versions.first.update_columns(created_at: 2.hours.ago)
        mail_snippet.update!(body: "updated body")
      end

      it "returns the snippet body that was in effect at that time" do
        expect(result.body).to eq "current body"
      end
    end

    context "with time before the snippet was created" do
      let(:time) { 1.day.ago }

      before { mail_snippet.versions.first.update_columns(created_at: Time.current) }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with time when the snippet was disabled" do
      let(:kind) { "impound_notification" }
      let(:body) { "disabled" }
      let(:is_enabled) { false }
      let(:time) { 1.hour.ago }

      before do
        mail_snippet.versions.first.update_columns(created_at: 2.hours.ago)
        mail_snippet.update!(is_enabled: true)
      end

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with snippet destroyed after the requested time" do
      let(:kind) { "header" }
      let(:body) { "old header" }
      let(:time) { 1.hour.ago }

      before do
        mail_snippet.versions.first.update_columns(created_at: 2.hours.ago)
        mail_snippet.destroy!
      end

      it "reifies the snippet as it was at that time" do
        expect(result.body).to eq "old header"
        expect(result.is_enabled).to be true
      end
    end

    context "with snippet created before paper_trail tracking started" do
      let(:time) { MailSnippet::PAPER_TRAIL_TRACKING_STARTED_AT - 1.day }

      before do
        mail_snippet.update_columns(created_at: MailSnippet::PAPER_TRAIL_TRACKING_STARTED_AT - 1.year)
        mail_snippet.versions.first.update_columns(created_at: MailSnippet::PAPER_TRAIL_TRACKING_STARTED_AT - 1.year)
      end

      it "returns the live snippet without reifying" do
        expect(result).to eq mail_snippet
        expect(result.body).to eq "current body"
      end
    end
  end

  describe "newsletter" do
    let(:mail_snippet) { FactoryBot.create(:mail_snippet, kind: :newsletter) }
    let(:mail_snippet_2) { FactoryBot.create(:mail_snippet, kind: :newsletter) }
    it "allows creating multiple" do
      expect(mail_snippet).to be_valid
      expect(mail_snippet_2).to be_valid
    end
  end
end
