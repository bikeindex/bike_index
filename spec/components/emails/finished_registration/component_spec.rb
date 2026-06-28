# frozen_string_literal: true

require "rails_helper"

RSpec.describe Emails::FinishedRegistration::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {ownership:, bike:} }
  let(:bike) { ownership.bike }
  let!(:tempo_snippet) do
    FactoryBot.create(:mail_snippet,
      kind: :tempo,
      is_enabled: tempo_snippet_is_enabled,
      body: "<p>tempo-snippet</p>")
  end
  let(:tempo_snippet_is_enabled) { true }

  context "non-stolen bike" do
    let(:ownership) { FactoryBot.create(:ownership_claimed) }
    it "renders registration content and locking guidelines" do
      expect(ownership.claim_message).to be_blank
      expect(component).to_not have_content("Registration complete")
      expect(component).to_not have_content("Your registration is active")
      expect(component).to_not have_content("Welcome to Bike Index")
      expect(component).to have_content("Congrats on registering your bike with Bike Index")
      expect(component).to have_content("Bike details")
      expect(component).to have_content("Protect your bike by following these locking guidelines")
      expect(component).to have_content("What's next?")
      expect(component).to have_content("Use a U-Lock")
      expect(component).to_not have_content("thieves are jerks")
      expect(component).to have_content("tempo-snippet")
    end
    context "tempo_snippet not is_enabled" do
      let(:tempo_snippet_is_enabled) { false }

      it "renders" do
        expect(ownership.claim_message).to be_blank
        expect(component).to have_content("Congrats on registering your bike with Bike Index")
        expect(component).to have_content("Protect your bike by following these locking guidelines")
        expect(component).to have_content("Use a U-Lock")
        expect(component).to_not have_content("thieves are jerks")
        expect(component).to_not have_content("tempo-snippet")
      end
    end
  end

  context "stolen bike" do
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
    let(:ownership) { bike.current_ownership }
    it "renders stolen bike content" do
      expect(bike.status_stolen?).to be_truthy
      expect(ownership.claim_message).to be_blank
      expect(component).to_not have_content("Recovery support")
      expect(component).to_not have_content("Registration complete")
      expect(component).to have_content("thieves are jerks")
      expect(component).to have_content("Hopefully you find the bike soon")
      expect(component).to have_content("Mark your bike recovered")
      expect(component).to have_content("Please consider")
      expect(component).to have_content("donating")
      expect(component).to_not have_content("What's next?")
      expect(component).to_not have_content("tempo-snippet")
    end
  end

  context "organized bike" do
    let(:organization) { FactoryBot.create(:organization_with_auto_user) }
    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }
    let(:ownership) { bike.current_ownership }
    it "renders organization name" do
      expect(ownership.claim_message).to be_blank
      expect(component).to have_content("Congrats on registering your bike with Bike Index and #{organization.short_name}")
      expect(component).to have_content("Protect your bike by following these locking guidelines")
      expect(component).to_not have_content("tempo-snippet")
    end
  end

  context "unclaimed bike" do
    let(:ownership) { FactoryBot.create(:ownership) }

    it "renders the confirm CTA" do
      expect(ownership.claimed?).to be_falsey
      expect(component).to_not have_content("Registration complete")
      expect(component).to_not have_content("Confirm your registration")
      expect(component).to have_content("Claim your bike")
      expect(component).to have_link("Confirm this #{bike.type}")
      expect(component).to_not have_content("What's next?")
    end
  end

  context "transferred registration" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:ownership) { FactoryBot.create(:ownership, bike:) }

    it "renders the claim message shell" do
      expect(ownership.claim_message).to be_present
      expect(component).to have_content("Claim your #{bike.type}")
      expect(component).to have_content("registered your bike on Bike Index")
      expect(component).to_not have_content("You're almost done registering!")
    end
  end

  context "organization snippets" do
    let(:organization) { FactoryBot.create(:organization_with_auto_user) }
    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }
    let(:ownership) { bike.current_ownership }
    let!(:welcome_snippet) do
      FactoryBot.create(:organization_mail_snippet,
        kind: "welcome",
        organization: organization,
        body: "<p>WELCOME SNIPPET</p>")
    end
    let!(:after_welcome_snippet) do
      FactoryBot.create(:organization_mail_snippet,
        kind: "after_welcome",
        organization: organization,
        body: "<p>AFTER WELCOME SNIPPET</p>")
    end
    let!(:security_snippet) do
      FactoryBot.create(:organization_mail_snippet,
        kind: "security",
        organization: organization,
        body: "<p>SECURITY SNIPPET</p>")
    end

    it "renders snippets and suppresses the default security block" do
      expect(component).to have_content("WELCOME SNIPPET")
      expect(component).to have_content("AFTER WELCOME SNIPPET")
      expect(component).to have_content("SECURITY SNIPPET")
      expect(component).to_not have_content("Protect your bike by following these locking guidelines")
      expect(component).to_not have_content("tempo-snippet")
    end
  end
end
