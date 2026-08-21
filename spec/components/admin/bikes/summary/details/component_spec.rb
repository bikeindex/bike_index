# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Bikes::Summary::Details::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "owner@bikeindex.org") }
  let(:options) { {} }
  let(:component) { render_inline(described_class.new(bike:, **options)) }

  it "renders the owner and creation, and no dev rows" do
    expect(component).to have_content("owner@bikeindex.org")
    expect(component).to have_content("self reg")
    expect(component).to_not have_content("status:")
  end

  context "with display_dev_info" do
    let(:options) { {display_dev_info: true} }

    # The id/status row replaces the .only-dev-visible inline <style> the partial needed
    it "renders the id and status row" do
      expect(component).to have_content("status:")
      expect(component).to have_content(bike.id.to_s)
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
      expect(component).to have_content("222")
    end

    # The stolen record renders the phone itself, so the summary drops its row
    context "with a stolen record" do
      let(:options) { {stolen_record: FactoryBot.create(:stolen_record, bike:)} }

      it "drops it" do
        expect(component).to_not have_content("222")
      end
    end
  end
end
