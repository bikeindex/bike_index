require "rails_helper"

RSpec.describe Pages::Registrations::Show::LegacyViewLink::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike) }
  let(:current_user) { FactoryBot.create(:user_confirmed) }
  let(:component) { described_class.new(bike:, current_user:) }

  context "bike_show_redesign_toggle enabled" do
    before { Flipper.enable_actor(:bike_show_redesign_toggle, current_user) }

    it "renders the invitation alert with a button that posts the bike to the toggle route" do
      render_inline(component)
      expect(page).to have_text("You're trying out the new bike viewer.")
      form = page.find("form[action='/my_account/toggle_show_redesign'][method='post']")
      expect(form).to have_css("input[name='bike_id'][value='#{bike.id}']", visible: :all)
      expect(form).to have_button("Switch back to the legacy viewer")
      # Refreshes its CSRF token client-side since it renders inside the cached redesign fragment
      expect(form["data-controller"]).to eq("csrf-refresh")
    end

    context "user opted into the legacy view" do
      let(:current_user) { FactoryBot.create(:user_confirmed, feature_registration_show_legacy: true) }

      it "renders the invitation alert with a plain link to the legacy viewer" do
        render_inline(component)
        expect(page).to have_text("You're trying out the new bike viewer.")
        expect(page).to have_link("view bike in legacy viewer", href: "/bikes/#{bike.id}")
        expect(page).to have_no_css("form[action='/my_account/toggle_show_redesign']")
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
