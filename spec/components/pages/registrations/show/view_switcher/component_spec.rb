require "rails_helper"

RSpec.describe Pages::Registrations::Show::ViewSwitcher::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike) }
  let(:current_user) { FactoryBot.create(:user_confirmed) }
  let(:available_views) { [[:public, nil]] }
  let(:component) do
    described_class.new(bike:, current_view: [:public, nil], available_views:, label: "Public", color: :gray, current_user:)
  end

  context "single view, toggle not enabled" do
    it "renders a plain badge" do
      render_inline(component)
      expect(page).to have_text("Public")
      expect(page).to have_no_link("View in Legacy Viewer")
    end
  end

  context "bike_show_redesign_toggle enabled" do
    before { Flipper.enable_actor(:bike_show_redesign_toggle, current_user) }

    it "renders the dropdown with a link to the legacy viewer" do
      render_inline(component)
      expect(page).to have_link("View in Legacy Viewer", href: "/bikes/#{bike.id}?no_redesign=true")
    end
  end

  context "with another view available" do
    let(:available_views) { [[:owner, nil], [:public, nil]] }

    # The view already showing has nowhere to go, so .twdropdown renders it as the label
    it "links the other view and leaves the current one unclickable" do
      render_inline(component)
      # organization_id=false so switching away from an org view drops it from the session
      expect(page).to have_link("View as owner of bike",
        href: "/registrations/#{bike.id}?organization_id=false&view_as=owner")
      expect(page).to have_css("li[role='menuitem'] span[data-active='true']", text: "Viewing as Public")
      expect(page).to have_no_css("a", text: "Viewing as")
    end
  end
end
