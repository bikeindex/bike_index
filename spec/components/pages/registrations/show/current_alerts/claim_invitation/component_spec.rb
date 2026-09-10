# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::CurrentAlerts::ClaimInvitation::Component, type: :component do
  let(:component) { described_class.new(bike:, current_user:, claim_message:) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "new-owner@example.com") }
  let(:current_user) { nil }
  let(:claim_message) { nil }

  context "signed in as someone the ownership is claimable by" do
    let(:current_user) { FactoryBot.create(:user_confirmed, email: "new-owner@example.com") }

    it "offers a one-click claim against the ownership" do
      render_inline(component)
      expect(page).to have_text("We're honored to have your bike on the Index")
      expect(page).to have_link("Claim bike", href: "/ownerships/#{bike.current_ownership.id}")
    end
  end

  context "arrived via the claim link while signed out" do
    let(:claim_message) { "new_registration" }

    it "pitches the registry and sends them to sign up against the ownership email" do
      render_inline(component)
      expect(page).to have_text("registered your bike on Bike Index")
      expect(page).to have_link("read more", href: "/about")
      # Signing up with the ownership's email is what makes the bike claimable
      claim_link = page.find_link("Sign up")["href"]
      expect(claim_link).to start_with("/users/new")
      expect(CGI.unescape(claim_link)).to include("email=new-owner@example.com")
      expect(CGI.unescape(claim_link)).to include("/registrations/#{bike.id}")
      expect(CGI.unescape(claim_link)).to include("t=#{bike.current_ownership.token}")
    end
  end

  # Someone signed in who isn't the claimant still gets the pitch, but not the sign-up —
  # they have an account, and ownerships#show is what tells them whose bike it is
  context "signed in as someone else, arrived via the claim link" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    let(:claim_message) { "new_registration" }

    it "offers the claim button, without the sign-up instruction" do
      render_inline(component)

      expect(page).to have_text("registered your bike on Bike Index")
      expect(page).to have_no_text("with the email address where you received")
      expect(page).to have_link("Claim bike", href: "/ownerships/#{bike.current_ownership.id}")
      expect(page).to have_no_link("Sign up")
    end
  end

  context "no claim message and not claimable" do
    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  context "already claimed" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:current_user) { bike.reload.user }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  context "unregistered parking notification bike" do
    let(:bike) { FactoryBot.create(:parking_notification_unregistered).bike }
    let(:claim_message) { "new_registration" }

    it "does not render — there's no owner to invite" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
