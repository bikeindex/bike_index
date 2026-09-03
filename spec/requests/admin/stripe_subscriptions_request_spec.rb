# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::StripeSubscriptionsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  base_url = "/admin/stripe_subscriptions"

  describe "#index" do
    let!(:stripe_subscription) { FactoryBot.create(:stripe_subscription) }

    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:collection).pluck(:id)).to eq([stripe_subscription.id])
    end
  end
end
