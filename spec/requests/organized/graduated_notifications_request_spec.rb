require "rails_helper"

RSpec.describe Organized::GraduatedNotificationsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/graduated_notifications" }
  include_context :request_spec_logged_in_as_organization_member

  let(:earliest_time) { Time.current - 2.years } # Have to set this for organization creation, or the org time_range is just the past year
  let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: 1.year.to_i, created_at: earliest_time) }
  let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: current_organization, serial_number: "sameserialnumber12111", owner_email: "testly@university.edu", created_at: earliest_time) }

  describe "index" do
    let!(:graduated_notification_pending) { FactoryBot.create(:graduated_notification_bike_graduated, organization: current_organization, bike: bike1) }
    let!(:graduated_notification_bike_graduated) { FactoryBot.create(:graduated_notification_bike_graduated, organization: current_organization) }
    let!(:graduated_notification_remaining) do
      FactoryBot.create(:graduated_notification,
        :marked_remaining,
        organization: current_organization,
        marked_remaining_at: Time.current - current_organization.graduated_notification_interval + 2.days)
    end
    it "renders with correct things" do
      expect(graduated_notification_pending.reload.status).to eq "bike_graduated"
      expect(GraduatedNotification.current.pluck(:id)).to match_array([graduated_notification_pending.id, graduated_notification_bike_graduated.id])

      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:search_status)).to eq "current"
      expect(assigns(:separate_secondary_notifications)).to be_falsey
      expect(assigns(:graduated_notifications).pluck(:id)).to match_array([graduated_notification_pending.id, graduated_notification_bike_graduated.id])

      get "#{base_url}?search_status=all"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:graduated_notifications).pluck(:id)).to match_array([graduated_notification_pending.id, graduated_notification_bike_graduated.id, graduated_notification_remaining.id])

      get "#{base_url}?search_email=testly%40univer"
      expect(response.status).to eq(200)
      expect(assigns(:graduated_notifications).pluck(:id)).to match_array([graduated_notification_pending.id])

      get "#{base_url}?search_email=testly%40univer&search_secondary=true"
      expect(response.status).to eq(200)
      expect(assigns(:separate_secondary_notifications)).to be_truthy
      expect(assigns(:graduated_notifications).pluck(:id)).to match_array([graduated_notification_pending.id])
    end
  end

  context "not-delivering organization" do
    it "still renders" do
      current_organization.update(graduated_notification_interval: nil)
      expect(current_organization.reload.deliver_graduated_notifications?).to be_falsey
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:search_status)).to eq "current"
    end
  end

  describe "show" do
    let!(:graduated_notification) { FactoryBot.create(:graduated_notification_bike_graduated, organization: current_organization, bike: bike1) }
    it "renders" do
      get "#{base_url}/#{graduated_notification.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:graduated_notification)).to eq graduated_notification
    end
    context "different organization's" do
      let!(:graduated_notification) { FactoryBot.create(:graduated_notification_bike_graduated) }
      it "raises not found" do
        get "#{base_url}/#{graduated_notification.id}"
        expect(response.status).to eq 404
      end
    end
  end
end
