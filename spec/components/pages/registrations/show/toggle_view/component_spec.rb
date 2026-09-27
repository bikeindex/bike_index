require "rails_helper"

RSpec.describe Pages::Registrations::Show::ToggleView::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike) }
  let(:component) { described_class.new(bike:) }

  it "renders the invitation alert that posts to the toggle route" do
    render_inline(component)
    expect(page).to have_text("Try out the new bike viewer!")
    form = page.find("form[action='/registrations/#{bike.id}/toggle_legacy_view'][method='post']")
    expect(form).to have_button("Switch to the new view")
  end
end
