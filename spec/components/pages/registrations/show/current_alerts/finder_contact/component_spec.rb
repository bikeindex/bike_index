# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::CurrentAlerts::FinderContact::Component, type: :component do
  let(:component) { described_class.new(bike:, organization:) }
  let(:organization) { FactoryBot.create(:organization, :paid) }
  # An e-scooter, so every string has to name the registration's cycle type
  let(:finder) { FactoryBot.create(:user_confirmed, name: "Finder Person", phone: "2223334444") }
  let(:bike) { FactoryBot.create(:bike, :impounded, :with_ownership_claimed, user: finder, cycle_type: "e-scooter").reload }

  it "shows how to reach the finder" do
    expect(bike.status_found?).to be_truthy
    render_inline(component)
    expect(page).to have_text("Contact the finder")
    expect(page).to have_text("This e-scooter was registered as found")
    expect(page).to have_text("Finder Person")
    expect(page).to have_link(finder.email, href: "mailto:#{finder.email}")
    expect(page).to have_link("222-333-4444", href: "tel:222-333-4444")
  end

  context "finder has no phone" do
    let(:finder) { FactoryBot.create(:user_confirmed, name: "Finder Person", phone: nil) }

    it "drops the phone row rather than rendering it empty" do
      render_inline(component)
      expect(page).to have_text("Finder Person")
      expect(page).to_not have_text("Phone")
    end
  end

  context "unpaid organization" do
    let(:organization) { FactoryBot.create(:organization) }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  context "no organization" do
    let(:organization) { nil }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  # An organization impounded it, so there's no finder to reach - the org owns the record
  context "impounded by an organization" do
    let(:bike) { FactoryBot.create(:impound_record, :with_organization).bike.reload }

    it "does not render" do
      expect(bike.status_found?).to be_falsey
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  describe "Wrapper::FinderContact::ComponentPreview" do
    let(:preview) { Pages::Registrations::Show::Wrapper::FinderContact::ComponentPreview.new }

    def notice_text(rendered) = rendered[:component]&.instance_variable_get(:@text)

    it "says so when no found registration exists to preview" do
      expect(notice_text(preview.paid_organization)).to match("found registration")
    end
  end
end
