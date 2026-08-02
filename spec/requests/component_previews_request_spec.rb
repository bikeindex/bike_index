# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ComponentPreviews", type: :request do
  # The preview renders against the seeded brakebills org
  let(:organization) { FactoryBot.create(:organization_brakebills) }
  let!(:parking_notification) { FactoryBot.create(:parking_notification, organization:) }

  # ParkingNotificationDetails calls display_dev_info? — the canary for helper methods
  it "renders a preview of a component that uses the controller helpers" do
    get "/rails/view_components/registrations/show/org_top_actions/wrapper/component/default"

    expect(response.status).to eq 200
    expect(response.body).to match("Notification#")
  end

  # FileUpload's preview renders whatever that same org has attached
  it "renders a preview built from a record's attachment" do
    organization.update(avatar: File.open(Rails.root.join("spec/fixtures/bike.jpg")))

    get "/rails/view_components/ui/forms/file_upload/component/with_existing_image"

    expect(response.status).to eq 200
    expect(response.body).to include("bike.jpg")
  end

  # These render a persisted bike rather than an in-memory one, so they're the previews
  # with something to lose if they ever ran against real data
  describe "registration show overlays" do
    let(:base_url) { "/rails/view_components/registrations/show/wrapper/component" }
    let!(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }

    it "renders the page with none of the overlays raised" do
      get "#{base_url}/no_overlay"

      expect(response.status).to eq 200
      expect(response.body).to_not match("Nothing to preview")
      expect(response.body).to_not match("<dialog")
    end

    it "renders the claim invitation over the page" do
      get "#{base_url}/claim_invitation"

      expect(response.status).to eq 200
      expect(response.body).to match("claim-invitation-modal")
    end

    # The recipient usually has no account yet, so the page behind it is the public one
    it "renders the signed-out claim invitation over the public view" do
      get "#{base_url}/claim_invitation_signed_out"

      expect(response.status).to eq 200
      expect(response.body).to match("claim-invitation-modal")

      component = Registrations::Show::Wrapper::ComponentPreview.new
        .claim_invitation_signed_out.dig(:locals, :component)

      expect(component.instance_variable_get(:@current_user)).to be_nil
      expect(component.instance_variable_get(:@view)).to eq [:public, nil]
    end

    it "renders the bike named by bike_id, through the view the select names" do
      other = FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization)
      staff = FactoryBot.create(:organization_admin, organization:)
      stub_const("ENV", ENV.to_hash.merge("LOOKBOOK_USER_ID" => staff.id.to_s))

      get "#{base_url}/no_overlay?view=org_admin&bike_id=#{other.id}"
      expect(response.status).to eq 200

      # Neither is reliably greppable out of a page, so check the component it built
      component = Registrations::Show::Wrapper::ComponentPreview.new
        .no_overlay(view: "org_admin", bike_id: other.id).dig(:locals, :component)

      expect(component.instance_variable_get(:@bike)).to eq other
      expect(component.instance_variable_get(:@view)).to eq [:staff, organization]
    end

    # ShowViews decides what the viewer may see, so an unentitled view falls back rather
    # than rendering a page the app never serves
    it "falls back to public when the lookbook user has no claim on the org" do
      outsider = FactoryBot.create(:user_confirmed)
      stub_const("ENV", ENV.to_hash.merge("LOOKBOOK_USER_ID" => outsider.id.to_s))

      component = Registrations::Show::Wrapper::ComponentPreview.new
        .no_overlay(view: "org_admin").dig(:locals, :component)

      expect(component.instance_variable_get(:@view)).to eq [:public, nil]
    end

    # Lookbook is mounted in production, where the bikes would be real people's
    it "renders a notice rather than the registration in production" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

      rendered = Registrations::Show::Wrapper::ComponentPreview.new.no_overlay

      expect(rendered[:component]).to be_a(UI::Alert::Component)
      expect(rendered[:component].instance_variable_get(:@text)).to match("disabled in production")
    end
  end
end
