# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::MyAccount::Show::Component, type: :component do
  let(:user) { FactoryBot.create(:user_confirmed, name: "Alexandra") }
  let(:view) { :list }
  let(:locks_tab) { false }
  let(:pagy) { Pagy::Offset.new(count: user.bikes.count, page: 1, limit: 10) }
  let(:component) do
    render_inline(described_class.new(user: user.reload, bikes: user.bikes.reorder(:id), pagy:, locks: user.locks, view:, locks_tab:))
  end

  context "without bikes or locks" do
    it "renders the header, the empty state and the prompts" do
      expect(component).to have_css("h1", text: "Alexandra on Bike Index")
      expect(component).to have_text(/0 bikes ·\s+0 locks/)
      expect(component).to have_text("No bikes registered yet")
      expect(component).to have_link("+ Add a bike", href: "/register")
      expect(component).to have_link("Update profile")
      expect(component).to have_link("Donate", href: %r{/donate\z})
      expect(component).to have_text("Strava")
    end

    context "on the locks tab" do
      let(:locks_tab) { true }

      it "renders the locks empty state, with no view toggle" do
        expect(component).to have_text("No locks registered yet")
        expect(component).to have_link("Add a lock")
        expect(component).not_to have_link("Grid view")
      end
    end
  end

  context "with bikes and a lock" do
    let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:, serial_number: "LISTED-123") }
    let!(:lock) { FactoryBot.create(:lock, user:, key_serial: "KEY-9") }

    it "renders the counts, the bikes and the view toggle" do
      expect(component).to have_text(/1 bike ·\s+1 lock/)
      expect(component).to have_link("Bikes")
      expect(component).to have_link("Locks", href: "/my_account?active_tab=locks")
      expect(component).to have_text("LISTED-123")
      expect(component).to have_link("Grid view", href: "/my_account?view=grid")
      expect(component).to have_css("a[aria-current=true][aria-label='List view']")
    end

    context "in the grid" do
      let(:view) { :grid }

      it "marks the grid as the current view" do
        expect(component).to have_css("a[aria-current=true][aria-label='Grid view']")
        expect(component).to have_text("LISTED-123")
      end
    end

    context "on the locks tab" do
      let(:locks_tab) { true }

      it "lists the locks" do
        expect(component).to have_text("KEY-9")
        expect(component).to have_link("Edit", href: "/locks/#{lock.id}/edit")
      end
    end
  end
end
