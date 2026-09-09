require "rails_helper"

RSpec.describe Pages::Registrations::Show::LegacyViewLink::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike) }
  let(:show_legacy) { false }
  let(:component) { described_class.new(bike:, show_legacy:) }
  let(:toggle_action) { "/registrations/#{bike.id}/toggle_legacy_view" }

  it "renders the opt-out alert with a button that posts to the toggle route" do
    render_inline(component)
    expect(page).to have_text("You're using the new bike viewer.")
    form = page.find("form[action='#{toggle_action}'][method='post']")
    expect(form).to have_button("Switch back to the legacy viewer")
    # Refreshes its CSRF token client-side since it renders inside the cached redesign fragment
    expect(form["data-controller"]).to eq("csrf-refresh")
  end

  context "viewer opted into the legacy view" do
    let(:show_legacy) { true }

    it "renders a plain link to the legacy viewer, the preference already set" do
      render_inline(component)
      expect(page).to have_link("view bike in legacy viewer", href: "/bikes/#{bike.id}")
      expect(page).to have_no_css("form[action='#{toggle_action}']")
    end
  end
end
