# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ComponentPreviews", type: :request do
  # The preview renders against the seeded brakebills org
  let(:organization) { FactoryBot.create(:organization_brakebills) }
  let!(:parking_notification) { FactoryBot.create(:parking_notification, organization:) }

  # ParkingNotificationDetails calls display_dev_info?, so it's the canary for
  # previews rendering through a controller with the helper methods
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
    expect(response.body).to match("thumb_bike.jpg")
  end
end
