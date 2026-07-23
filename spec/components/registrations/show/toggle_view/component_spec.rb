require "rails_helper"

RSpec.describe Registrations::Show::ToggleView::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike) }
  let(:current_user) { FactoryBot.create(:user_confirmed) }
  let(:component) { described_class.new(bike:, current_user:) }

  context "bike_show_redesign_toggle enabled" do
    before { Flipper.enable_actor(:bike_show_redesign_toggle, current_user) }

    it "renders the invitation alert that posts the bike to the toggle route" do
      render_inline(component)
      expect(page).to have_text("Try out the new bike viewer!")
      form = page.find("form[action='/my_account/toggle_show_redesign'][method='post']")
      expect(form).to have_css("input[name='bike_id'][value='#{bike.id}']", visible: :all)
      expect(form).to have_button("Switch to the new view")
    end

    context "redesign enabled for the user" do
      before { Flipper.enable_actor(:bike_show_redesign, current_user) }

      it "explains the legacy view and links back to the new viewer" do
        render_inline(component)
        expect(page).to have_text("Viewing legacy viewer. By default you use the new viewer.")
        expect(page).to have_link("View in new viewer", href: "/registrations/#{bike.id}")
        form = page.find("form[action='/my_account/toggle_show_redesign'][method='post']")
        expect(form).to have_css("input[name='bike_id'][value='#{bike.id}']", visible: :all)
        expect(form).to have_button("Switch to legacy viewer by default")
      end
    end
  end

  context "bike_show_redesign_toggle not enabled" do
    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  context "no current_user" do
    let(:current_user) { nil }
    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
