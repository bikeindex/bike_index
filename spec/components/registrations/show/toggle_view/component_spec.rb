require "rails_helper"

RSpec.describe Registrations::Show::ToggleView::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike) }
  let(:current_user) { FactoryBot.create(:user_confirmed) }
  let(:component) { described_class.new(bike:, current_user:) }

  it "renders the invitation alert that posts the bike to the toggle route" do
    render_inline(component)
    expect(page).to have_text("Try out the new view!")
    form = page.find("form[action='/my_account/toggle_show_redesign'][method='post']")
    expect(form).to have_css("input[name='bike_id'][value='#{bike.id}']", visible: :all)
    expect(form).to have_button("Switch to the new view")
  end

  context "no current_user" do
    let(:current_user) { nil }
    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
