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

    let(:organization) { FactoryBot.create(:organization) }
    let(:kind) { "parked_incorrectly_notification" }
    let!(:mail_snippet) do
      FactoryBot.create(:mail_snippet, kind:, organization:, is_enabled: true, body: "current body")
    end

    it "returns the current snippet without time" do
      expect(MailSnippet.for_organization(organization_id: organization.id, kind:)).to eq mail_snippet
    end

    it "returns nil for unknown organization" do
      expect(MailSnippet.for_organization(organization_id: organization.id + 999, kind:)).to be_nil
    end

    context "when currently disabled" do
      it "returns nil" do
        mail_snippet.update!(is_enabled: false)
        expect(MailSnippet.for_organization(organization_id: organization.id, kind:)).to be_nil
      end
    end

    context "with time" do
      let(:past_time) { 1.hour.ago }

      it "returns the snippet body that was in effect at that time" do
        # Backdate the create version so updates count as later
        mail_snippet.versions.first.update_columns(created_at: 2.hours.ago)
        mail_snippet.update!(body: "updated body")

        result = MailSnippet.for_organization(organization_id: organization.id, kind:, time: past_time)
        expect(result.body).to eq "current body"
        expect(MailSnippet.for_organization(organization_id: organization.id, kind:).body).to eq "updated body"
      end

      it "returns nil if the snippet did not exist yet at that time" do
        # Move the create version to be after the query time
        mail_snippet.versions.first.update_columns(created_at: Time.current)

        result = MailSnippet.for_organization(organization_id: organization.id, kind:, time: 1.day.ago)
        expect(result).to be_nil
      end

      it "returns nil if the snippet was disabled at that time" do
        disabled_snippet = FactoryBot.create(:mail_snippet, kind: "impound_notification", organization:, is_enabled: false, body: "disabled")
        disabled_snippet.versions.first.update_columns(created_at: 2.hours.ago)
        disabled_snippet.update!(is_enabled: true)

        result = MailSnippet.for_organization(organization_id: organization.id, kind: "impound_notification", time: past_time)
        expect(result).to be_nil
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
