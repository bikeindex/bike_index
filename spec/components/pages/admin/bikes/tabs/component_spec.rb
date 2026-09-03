# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Bikes::Tabs::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, :with_ownership, manufacturer: Manufacturer.other, manufacturer_other: "Cool Bikes") }
  let(:active) { :edit }
  let(:options) { {} }
  let(:component) { render_inline(described_class.new(bike:, active:, **options)) }
  let(:tab_labels) { component.css("nav a").map { |tab| tab.text.squish } }

  it "renders the bike and every tab, with the active one marked" do
    expect(component).to have_content(bike.title_string)
    expect(tab_labels).to eq ["Edit", "Duplicates 0", "Messages 0", "Listings 0", "Ownerships 1",
      "Stickers 0", "Promoted alerts 0", "Recoveries 0"]
    expect(component.css("nav a[aria-current]").map { |tab| tab.text.squish }).to eq ["Edit"]
    expect(component).to have_link("Edit", href: "/admin/bikes/#{bike.id}/edit")
    expect(component).to have_link("non-admin view", href: "/bikes/#{bike.id}")
  end

  context "with an invalid active tab" do
    let(:active) { :party }

    it "raises" do
      expect { component }.to raise_error(ArgumentError, /party/)
    end
  end

  describe "the stolen tab" do
    it "is absent without a stolen record" do
      expect(tab_labels).to_not include(a_string_starting_with("Stolen"))
    end

    context "with an unapproved stolen record" do
      let(:bike) { FactoryBot.create(:stolen_bike) }
      let(:stolen_record) { bike.current_stolen_record }
      before { stolen_record.update(approved: false) }

      it "renders it, unapproved" do
        expect(tab_labels).to include "Stolen ❌"
        expect(component).to have_link("Stolen ❌",
          href: "http://test.host/admin/stolen_bikes/#{stolen_record.id}/edit?stolen_record_id=true")
      end
    end

    context "with an approved stolen record" do
      let(:bike) { FactoryBot.create(:stolen_bike) }
      before { bike.current_stolen_record.update(approved: true) }

      it "renders it, approved" do
        expect(tab_labels).to include "Stolen ✅"
      end
    end
  end

  describe "the impound tab" do
    it "is absent without impound records" do
      expect(tab_labels).to_not include(a_string_starting_with("Impoundings"))
    end

    # The count is two tables added together, so one of each
    context "with an impound record and a claim" do
      before do
        FactoryBot.create(:impound_claim_with_stolen_record, bike:)
        FactoryBot.create(:impound_record, bike:)
      end

      it "counts both" do
        expect(tab_labels).to include "Impoundings 2"
      end
    end

    # The page renders either way, so it can't be the one tab that vanishes underneath itself
    context "on the impound tab without any" do
      let(:active) { :impound }

      it "renders it, active" do
        expect(component.css("nav a[aria-current]").map { |tab| tab.text.squish }).to eq ["Impoundings 0"]
      end
    end
  end

  describe "the recovery displays tab" do
    it "is absent" do
      expect(tab_labels).to_not include "Recovery displays"
    end

    context "with display_recovery" do
      let(:options) { {display_recovery: true} }

      it "renders" do
        expect(component).to have_link("Recovery displays", href: "/admin/recovery_displays?search_bike_id=#{bike.id}")
      end
    end

    context "with a recovered stolen record" do
      let(:bike) { FactoryBot.create(:stolen_bike) }
      before { bike.current_stolen_record.add_recovery_information }

      it "renders, without being asked" do
        expect(tab_labels).to include "Recovery displays"
      end
    end
  end

  describe "alerts" do
    it "renders none" do
      expect(component.css("[role='alert']")).to be_empty
    end

    context "with a deleted bike" do
      before { bike.destroy }

      it "renders the deleted alert" do
        expect(component).to have_content("#{bike.type_titleize} deleted")
      end
    end

    context "with a likely spam bike" do
      before { bike.update(likely_spam: true) }

      it "renders the spam alert" do
        expect(component).to have_content("This #{bike.type} is likely spam")
      end
    end

    context "with an example bike" do
      before { bike.update(example: true) }

      it "renders the example alert" do
        expect(component).to have_content("#{bike.type_titleize} is a test registration")
      end
    end

    context "with a user hidden bike" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership, marked_user_hidden: true) }

      it "renders the hidden alert" do
        expect(component).to have_content("Marked hidden")
        expect(component).to have_content("Hidden by the user")
      end
    end
  end
end
