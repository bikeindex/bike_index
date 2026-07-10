require "rails_helper"

RSpec.describe "RegistrationsController#show", type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/registrations" }
  # Required when rendering bike details, otherwise it raises ReadOnlyError
  before { RearGearType.fixed }

  context "consumer view" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_primary_activity) }
    let(:current_user) { bike.reload.user }

    it "renders the redesigned consumer view with owner actions" do
      get "#{base_url}/#{bike.id}"
      expect(response.status).to eq(200)
      # Renders full-width, not wrapped in the content skeleton's sidebar
      expect(response.body).to_not include("primary-content-menu")
      body = whitespace_normalized_body_text
      expect(body).to match("Your bike")
      expect(body).to match("Activity")
      expect(body).to match("Mark stolen")
      expect(body).to match("Add photo")
    end

    context "current_user not owner" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      it "shows the public view and hides owner actions" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Activity")
        expect(body).to match("Public view")
        expect(body).to match("Share")
        expect(body).to_not match("Sell on Marketplace")
        expect(body).to_not match("Mark stolen")
        expect(body).to_not match("Add photo")
      end
    end

    context "current_user previously owned the bike (sent away)" do
      let(:previous_owner) { bike.reload.user }
      let(:current_user) { previous_owner }
      # Capture the original owner, then transfer to a new owner (demoting the
      # original's ownership to non-current)
      before do
        previous_owner
        FactoryBot.create(:ownership, bike:, user: FactoryBot.create(:user_confirmed))
      end
      it "shows the sent-away badge and hides owner actions" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("No longer your bike")
        expect(body).to_not match("Your bike")
        expect(body).to_not match("Mark stolen")
      end
    end

    context "with photos" do
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike, image: File.open(Rails.root.join("spec/fixtures/bike.jpg"))) }
      let!(:public_image2) { FactoryBot.create(:public_image, imageable: bike, image: File.open(Rails.root.join("spec/fixtures/bike.jpg"))) }
      it "renders the add-photo link but no replace/remove links" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Add photo")
        expect(body).to_not match("Replace")
        expect(body).to_not match("Remove")
        expect(response.body).to match(edit_bike_path(bike, edit_template: "photos"))
      end
    end

    context "stolen bike" do
      let!(:stolen_record) { FactoryBot.create(:stolen_record, bike:, phone: "3025551234", phone_for_everyone: true) }
      it "renders the redesign theft details, hiding mark-stolen and marketplace for the owner" do
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq(200)
        body = whitespace_normalized_body_text
        expect(body).to match("Activity")
        expect(body).to match("Share my page")
        expect(body).to_not match("Mark stolen")
        expect(body).to_not match("Sell on Marketplace")
        # Theft details always show a location row, even with no location on file
        expect(body).to match("No location given")
        # Owner phone shows when phone visibility permits
        expect(body).to match("3025551234")
      end
    end
  end

  context "anonymous viewer of an ownerless bike" do
    # A bike with no ownership has owner == nil; a logged-out viewer (current_user
    # nil) must not match the owner view via nil == nil
    let(:bike) { FactoryBot.create(:bike) }
    let(:current_user) { nil }

    it "renders the public view, not the owner view" do
      get "#{base_url}/#{bike.id}"
      expect(response.status).to eq(200)
      body = whitespace_normalized_body_text
      expect(body).to match("Public view")
      expect(body).to_not match("Your bike")
      expect(body).to_not match("Mark stolen")
      expect(body).to_not match("Sell on Marketplace")
      expect(body).to_not match("Add photo")
    end
  end

  context "admin panel" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }

    context "org staff (admin)" do
      let(:current_user) { FactoryBot.create(:organization_admin, organization: organization) }
      it "renders the admin redesign" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Admin / Staff")
        expect(body).to match("Bike details")
        expect(body).to match("Owner & access")
        expect(body).to match(bike.owner_email)
      end
    end

    context "limited role (member_no_bike_edit)" do
      let(:current_user) { FactoryBot.create(:organization_user, organization: organization, role: "member_no_bike_edit") }
      it "hides owner contact and shows the restricted card" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Limited · RA")
        expect(body).to match("Restricted for your role")
        expect(body).to match("Bike details")
        expect(body).to_not match(bike.owner_email)
      end
    end

    context "removing the organization via organization_id=false" do
      let(:current_user) { FactoryBot.create(:organization_admin, organization: organization) }
      it "drops the admin view on the same request, not only on reload" do
        # With the org in the session (their default), the admin view renders
        get "#{base_url}/#{bike.id}"
        expect(whitespace_normalized_body_text).to match("Admin / Staff")

        # Removing the org should drop the admin view on this request, not only
        # after a subsequent reload
        get "#{base_url}/#{bike.id}", params: {organization_id: "false"}
        expect(whitespace_normalized_body_text).to_not match("Admin / Staff")
      end
    end

    context "view_as switching" do
      let(:current_user) { FactoryBot.create(:organization_admin, organization: organization) }
      it "offers a switcher, applies an allowed view_as, and rejects a disallowed one" do
        get "#{base_url}/#{bike.id}"
        expect(whitespace_normalized_body_text).to match("Admin / Staff")
        expect(response.body).to include("view_as=public")

        # An allowed view_as applies
        get "#{base_url}/#{bike.id}", params: {view_as: "public"}
        body = whitespace_normalized_body_text
        expect(body).to_not match("Admin / Staff")
        expect(body).to match("Public view")

        # A disallowed view_as flashes and falls back to the admin view
        get "#{base_url}/#{bike.id}", params: {view_as: "owner"}
        body = whitespace_normalized_body_text
        expect(body).to match("Admin / Staff")
        expect(body).to match("not allowed to view this registration")
      end
    end

    context "superuser view_as options" do
      let(:current_user) { FactoryBot.create(:superuser) }
      let!(:brakebills) { FactoryBot.create(:organization, name: "Brakebills") }
      it "offers every view and renders the owner and org-limited perspectives" do
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq(200)
        body = whitespace_normalized_body_text
        expect(body).to match("View as owner of bike")
        expect(body).to match("View as #{brakebills.short_name} staff")
        expect(body).to match("View as #{brakebills.short_name} limited")
        # public is the superuser's default/current view
        expect(body).to match("Viewing as Public")

        # Renders the owner view even though they don't own the bike
        get "#{base_url}/#{bike.id}", params: {view_as: "owner"}
        body = whitespace_normalized_body_text
        expect(body).to match("Your bike")
        expect(body).to match("Mark stolen")

        # Renders an org panel as limited
        get "#{base_url}/#{bike.id}", params: {view_as: "#{brakebills.to_param}.limited"}
        body = whitespace_normalized_body_text
        expect(body).to match("Limited")
        expect(body).to_not match("Admin / Staff")
      end
    end
  end
end
