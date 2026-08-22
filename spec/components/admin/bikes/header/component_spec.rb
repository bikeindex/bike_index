# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Bikes::Header::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, :with_ownership) }
  let(:options) { {} }
  let(:component) { render_inline(described_class.new(bike:, active: :edit, **options)) }

  it "renders the tabs and the summary, without theft or recovery" do
    expect(component.css("nav a[aria-current]").map { |tab| tab.text.squish }).to eq ["Edit"]
    expect(component).to have_content(bike.owner_email)
    expect(component).to_not have_content("Theft information")
    expect(component).to_not have_content("Recovery Information")
  end

  # Every admin screen scoped to a bike reaches it through an unscoped find, which can miss
  context "without a bike" do
    let(:bike) { nil }

    it "says so rather than raising" do
      expect(component).to have_content("No registration present")
      expect(component.css("nav a")).to be_empty
    end
  end

  context "with a stolen record" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    before { bike.current_stolen_record.update(theft_description: "Taken from the rack") }

    it "renders the theft information" do
      expect(component).to have_content("Theft information")
      expect(component).to have_content("Taken from the rack")
      expect(component).to_not have_content("Recovery Information")
    end

    context "recovered" do
      before { bike.current_stolen_record.add_recovery_information }

      it "renders the recovery information too" do
        expect(component).to have_content("Recovery Information")
      end
    end
  end
end
