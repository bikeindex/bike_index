require "rails_helper"

RSpec.describe Organized::GraduatedNotificationsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/graduated_notifications" }
  include_context :request_spec_logged_in_as_organization_member

  let(:current_organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: 1.year.to_i) }
  let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership, organization: current_organization, serial_number: "sameserialnumber12111", owner_email: "testly@university.edu", created_at: Time.current - 2.years) }

  describe "index" do
    let!(:graduated_notification_pending) { FactoryBot.create(:graduated_notification_active, organization: current_organization, bike: bike1) }
    let!(:graduated_notification_active) { FactoryBot.create(:graduated_notification_active, organization: current_organization) }
    let!(:graduated_notification_remaining) do
      FactoryBot.create(:graduated_notification,
                        :marked_remaining,
                        organization: current_organization,
                        marked_remaining_at: Time.current - current_organization.graduated_notification_interval + 2.days)
    end
    it "renders with correct things" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:graduated_notifications).pluck(:id)).to match_array([graduated_notification_pending.id, graduated_notification_active.id])

      get "#{base_url}?search_status=all"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:graduated_notifications).pluck(:id)).to match_array([graduated_notification_pending.id, graduated_notification_active.id, graduated_notification_remaining.id])

      get "#{base_url}?search_email=testly%40univer"
      expect(response.status).to eq(200)
      expect(assigns(:graduated_notifications).pluck(:id)).to match_array([graduated_notification_pending.id])
    end
  end

  describe "show" do
    let!(:graduated_notification1) { FactoryBot.create(:graduated_notification_active, organization: current_organization, bike: bike1) }
    it "renders" do
      get "#{base_url}/#{graduated_notification1.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:graduated_notification)).to eq graduated_notification1
    end
    context "secondary notification" do
      let(:bike2) { FactoryBot.create(:bike_organized, :with_ownership, organization: current_organization, serial_number: "sameserialnumber12111", owner_email: "testly@university.edu") }
      let!(:graduated_notification2) { FactoryBot.create(:graduated_notification, organization: current_organization, bike: bike2) }
      it "renders" do
        expect(graduated_notification2.secondary_notification?).to be_truthy
        expect(graduated_notification2.primary_notification_id).to eq graduated_notification1.id
        get "#{base_url}/#{graduated_notification2.id}"
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(assigns(:graduated_notification)).to eq graduated_notification2
      end
    end
  end
end
