# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Bikes::Summary::Details::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "owner@bikeindex.org") }
  let(:options) { {} }
  let(:component) { render_inline(described_class.new(bike:, **options)) }

  # The row's own label - matching on a value risks colliding with a factory sequence
  # somewhere else in the summary, which is how the phone assertion used to fail on CI
  def row_labels
    component.css("table.table-list tr td:first-child").map { |td| td.text.squish }
  end

  it "renders the owner and creation, and no dev rows" do
    expect(component).to have_content("owner@bikeindex.org")
    expect(component).to have_content("self reg")
    expect(component).to_not have_content("status:")
  end

  context "with display_dev_info" do
    let(:options) { {display_dev_info: true} }

    # The id/status row replaces the .only-dev-visible inline <style> the partial needed
    it "renders the id and status row" do
      expect(row_labels).to include "ID"
      expect(component.css("tr td code").map { |code| code.text.strip }).to include bike.id.to_s
    end
  end

  context "with a creation organization" do
    let(:bike) { FactoryBot.create(:bike_organized, owner_email: "owner@bikeindex.org") }

    it "links it instead of the creator" do
      expect(component).to have_link(bike.creation_organization.name)
      expect(component.css("small").map { |e| e.text.strip }).to_not include "self reg"
    end
  end

  context "with a phone and no stolen record" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership, phone: "2223334444") }

    it "renders the phone" do
      expect(row_labels).to include "Phone"
    end

    # The stolen record renders the phone itself, so the summary drops its row
    context "with a stolen record" do
      let(:options) { {stolen_record: FactoryBot.create(:stolen_record, bike:)} }

      it "drops it" do
        expect(row_labels).to_not include "Phone"
      end
    end
  end
end
