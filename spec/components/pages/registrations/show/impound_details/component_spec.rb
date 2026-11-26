# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::ImpoundDetails::Component, type: :component do
  let(:component) { described_class.new(bike:) }

  context "org-impounded bike" do
    let(:bike) { FactoryBot.create(:impound_record, :with_organization).bike.reload }

    it "renders the impound card with the impounded-at date" do
      render_inline(component)
      expect(page).to have_text("Impound details")
      expect(page).to have_text("Impounded at")
    end
  end

  context "organization viewing its impound record" do
    let(:component) { described_class.new(bike:, organization:) }
    let(:impound_record) { FactoryBot.create(:impound_record, :with_organization, :with_address_record, location:) }
    let(:organization) { impound_record.organization }
    let(:location) { FactoryBot.create(:location, :with_address_record, address_in: :new_york, name: "Back lot") }
    let(:bike) { impound_record.bike.reload }

    it "renders the location, the full impounded-from address and the notes, newest first" do
      FactoryBot.create(:impound_record_update, impound_record:, kind: "note", notes: "Owner emailed")
      FactoryBot.create(:impound_record_update, impound_record:, kind: "note", notes: "Owner called, picking up Tuesday")
      FactoryBot.create(:impound_record_update, impound_record:, kind: "note", notes: " ")
      render_inline(component)
      expect(page).to have_text("#{organization.short_name} impound record")
      expect(page).to have_text(/Current location\s*Back lot\s*278 Broadway/)
      expect(page).to have_text("1300 W 14th Pl, Chicago, IL 60608")
      expect(page).to have_text(/Owner called, picking up Tuesday.*Owner emailed/m)
      expect(page).to have_css("small .localizeTime", count: 2)
      # Pinned where it was impounded from, not at the location holding it
      expect(page).to have_css("[data-registrations--show--map-latitude-value='41.8624488']")
    end

    it "renders the public card to another organization" do
      FactoryBot.create(:impound_record_update, impound_record:, kind: "note", notes: "Owner emailed")
      render_inline(described_class.new(bike:, organization: FactoryBot.create(:organization)))
      expect(page).to have_text("Impound details")
      expect(page).not_to have_text("Owner")
      expect(page).not_to have_text("Back lot")
    end

    it "pins the public card where it was impounded from, rounded" do
      render_inline(described_class.new(bike:))
      expect(page).to have_text("Impound details")
      expect(page).to have_css("[data-registrations--show--map-latitude-value='#{41.8624488.round(Bike::PUBLIC_COORD_LENGTH)}']")
      expect(page).to have_text(/Location\s*Chicago, IL 60608/)
      expect(page).not_to have_text("New York")
    end
  end

  context "found bike" do
    let(:bike) { FactoryBot.create(:bike, :impounded).reload }

    it "renders the found card with the found-at date" do
      render_inline(component)
      expect(page).to have_text("Found details")
      expect(page).to have_text("Found at")
    end
  end

  context "non-impounded bike" do
    let(:bike) { FactoryBot.create(:bike) }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
