require "rails_helper"

RSpec.describe Pages::Registrations::Show::ToggleView::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike) }
  let(:show_legacy) { false }
  let(:component) { described_class.new(bike:, show_legacy:) }
  let(:toggle_action) { "/registrations/#{bike.id}/toggle_legacy_view" }

  it "explains the legacy view and links back to the new viewer" do
    render_inline(component)
    expect(page).to have_text("Legacy viewer (by default you use the new viewer)")
    expect(page).to have_link("View in new viewer", href: "/registrations/#{bike.id}")
    form = page.find("form[action='#{toggle_action}'][method='post']")
    expect(form).to have_button("Switch to legacy viewer by default.")
  end

  context "viewer opted into the legacy view" do
    let(:show_legacy) { true }

    it "renders the invitation alert that posts to the toggle route" do
      render_inline(component)
      expect(page).to have_text("Try out the new bike viewer!")
      form = page.find("form[action='#{toggle_action}'][method='post']")
      expect(form).to have_button("Switch to the new view")
    end
  end

  context "not toggleable" do
    let(:component) { described_class.new(bike:, show_legacy:, toggleable: false) }
    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
