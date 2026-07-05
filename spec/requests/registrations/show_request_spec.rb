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

    context "with photos" do
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike, image: File.open(Rails.root.join("spec/fixtures/bike.jpg"))) }
      it "renders replace/remove links to the photos edit page" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Replace")
        expect(body).to match("Remove")
        expect(response.body).to match(edit_bike_path(bike, edit_template: "photos"))
      end
    end

    context "stolen bike" do
      let!(:stolen_record) { FactoryBot.create(:stolen_record, bike:) }
      it "still renders the redesign" do
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq(200)
        expect(whitespace_normalized_body_text).to match("Activity")
      end
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
  end
end
