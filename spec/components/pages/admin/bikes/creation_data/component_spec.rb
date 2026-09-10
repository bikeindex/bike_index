# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Bikes::CreationData::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, :with_ownership) }
  let(:options) { {} }
  let(:component) { render_inline(described_class.new(bike:, **options)) }
  let(:content) { component.at_css("[data-ui--collapse-target='content']") }

  it "renders the ownership, collapsed behind a trigger" do
    expect(component).to have_button("Creation data & developer information")
    expect(content["class"]).to include "tw:hidden"
    expect(component).to have_content("Ownership")
    expect(component).to have_content("No BParams exist")
  end

  it "marks the bike's own ownership current" do
    expect(component.text).to match(/Ownership\s+Current/)
  end

  context "with display_dev_info" do
    let(:options) { {display_dev_info: true} }

    # Dev info means it always shows, so a trigger could only ever close it
    it "renders open, with no trigger" do
      expect(component).to_not have_button("Creation data & developer information")
      expect(content["class"]).to_not include "tw:hidden"
      expect(component).to have_content("ID: #{bike.current_ownership.id}")
    end
  end

  context "with a b_param" do
    let!(:b_param) { FactoryBot.create(:b_param, created_bike_id: bike.id) }

    it "renders it instead of the empty message" do
      expect(component).to_not have_content("No BParams exist")
      expect(component).to have_content("BParam")
    end
  end

  context "with a transferred ownership" do
    before { FactoryBot.create(:ownership, bike:, current: false) }

    it "says so" do
      expect(component).to have_content("transferred")
    end
  end
end
