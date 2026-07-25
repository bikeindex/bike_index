# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ComponentPreviews", type: :request do
  # The preview renders against the seeded brakebills org
  let(:organization) { FactoryBot.create(:organization_brakebills) }
  let!(:parking_notification) { FactoryBot.create(:parking_notification, organization:) }

  # Previews go through ComponentPreviewsController so components can call the
  # ControllerHelpers methods they use everywhere else (here: display_dev_info?)
  it "renders a preview of a component that uses the controller helpers" do
    get "/rails/view_components/registrations/show/org_top_actions/wrapper/component/default"

    expect(response.status).to eq 200
    expect(response.body).to match("Notification#")
  end
end
