# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Info::Show::Component, type: :component do
  let(:component) { render_inline(described_class.new(organization:, current_user:)) }
  let(:organization) { FactoryBot.create(:organization) }
  let(:current_user) { FactoryBot.create(:organization_admin, organization:) }

  it "offers to copy the registration link, and to show its QR code" do
    registration_url = "http://test.host/register/#{organization.slug}"
    expect(component).to have_text registration_url
    expect(component).to have_css "button[data-ui--copy-button-text-value='#{registration_url}']", text: "Copy link"
    expect(component).to have_link "Download QR code", href: "/register/#{organization.slug}.png"
  end

  it "suggests adding registrations and inviting the team while there are few of either" do
    expect(component).to have_link "Add a registration", href: "/o/#{organization.slug}/registrations/new"
    expect(component).to have_text "Organization set up next steps"
    expect(component).to have_link "Invite your team", href: "/o/#{organization.slug}/users/new"
  end

  context "with 3 registrations and 3 members" do
    before do
      FactoryBot.create_list(:bike_organized, 3, creation_organization: organization)
      FactoryBot.create_list(:organization_user, 2, organization:)
    end

    it "suggests neither, so has no next steps" do
      expect(component).to_not have_text "Organization set up next steps"
      expect(component).to_not have_link "Add a registration"
      expect(component).to_not have_link "Invite your team"
    end
  end

  describe "invoices" do
    let(:invoice) { FactoryBot.create(:invoice_paid, organization:) }
    before { organization.update(updated_at: Time.current) if invoice }

    it "says when the next one is due, in place of the next steps" do
      expect(component).to have_text "Your organization has paid functionality."
      expect(component).to have_text "Next invoice due"
      expect(component).to have_css ".localizeTime.withPreposition"
      expect(component).to_not have_text "Organization set up next steps"
    end

    context "endless" do
      let(:invoice) { FactoryBot.create(:invoice_paid, organization:, is_endless: true) }

      it "says none are upcoming" do
        expect(component).to have_text "Your organization has paid functionality."
        expect(component).to have_text "No invoices upcoming."
      end

      context "with another invoice" do
        before { FactoryBot.create(:invoice_paid, organization:) }

        it "says when it's due" do
          expect(component).to have_text "Next invoice due"
          expect(component).to_not have_text "No invoices upcoming"
        end
      end
    end

    context "without one" do
      let(:invoice) { nil }

      it "doesn't mention paid functionality" do
        expect(component).to_not have_text "paid functionality"
      end
    end
  end

  describe "setting a password" do
    let(:current_user) { FactoryBot.create(:organization_admin, organization:, passwordless_user:, created_at:) }
    let(:passwordless_user) { true }
    let(:created_at) { 10.minutes.ago }

    it "offers it to someone who just signed up without one" do
      expect(component).to have_link "Set a password"
    end

    context "signed up over an hour ago" do
      let(:created_at) { 2.hours.ago }

      it "doesn't" do
        expect(component).to_not have_link "Set a password"
      end
    end

    context "with a password" do
      let(:passwordless_user) { false }

      it "doesn't" do
        expect(component).to_not have_link "Set a password"
      end
    end
  end

  context "a member who isn't an admin" do
    let(:current_user) { FactoryBot.create(:organization_user, organization:) }

    it "doesn't offer inviting, which only an admin can do" do
      expect(component).to have_link "Add a registration"
      expect(component).to_not have_link "Invite your team"
    end
  end
end
