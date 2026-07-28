# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Bikes::Tabs::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:, **options)) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership) }
  let(:options) { {} }

  it "renders the bike summary and every tab, none active" do
    expect(component.css(".nav-tabs .nav-link").map { it.text.strip.split(/\s+/).first })
      .to eq(%w[Edit Duplicates Messages Listings Ownerships Stickers Promoted Recoveries])
    expect(component.css(".nav-tabs .nav-link.active")).to be_blank
    expect(component.text).to include(bike.owner_email)
    expect(component.text).to include(bike.title_string)
  end

  context "with an active_tab" do
    let(:options) { {active_tab: "bikes-edit"} }

    it "marks only that tab active" do
      expect(component.css(".nav-tabs .nav-link.active").map { it.text.strip }).to eq(["Edit"])
    end
  end

  context "with an active_tab matching no tab" do
    let(:options) { {active_tab: "ownerships-edit"} }

    it "marks nothing active" do
      expect(component.css(".nav-tabs .nav-link.active")).to be_blank
    end
  end

  context "without a bike" do
    let(:bike) { nil }

    it "says so rather than raising" do
      expect(component.css("h1.text-danger").text.strip).to eq "No Bike present"
      expect(component.css(".nav-tabs")).to be_blank
    end
  end

  context "with a stolen bike" do
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership) }

    it "finds the current stolen record and adds the Stolen tab" do
      expect(component.text).to match(/Theft information/)
      expect(component.css(".nav-tabs .nav-link").map { it.text.strip.split(/\s+/).first }).to include("Stolen")
      expect(component.text).to_not match(/Recovery Information/)
    end

    context "recovered" do
      before { bike.current_stolen_record.add_recovery_information }

      it "renders the recovery info and its tab" do
        expect(component.text).to match(/Recovery Information/)
        expect(component.css(".nav-tabs .nav-link").map { it.text.strip }).to include("Recovery displays")
      end
    end
  end

  context "with a deleted bike" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership, deleted_at: Time.current) }

    it "renders the deleted alert" do
      expect(component.css(".alert-danger").text).to match(/Deleted/)
    end
  end

  context "with an impound record" do
    let!(:impound_record) { FactoryBot.create(:impound_record, bike:) }

    it "renders the impound tab" do
      expect(component.css(".nav-tabs .nav-link").map { it.text.strip.split(/\s+/).first }).to include("Impoundings")
    end
  end
end
