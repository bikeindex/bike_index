require "rails_helper"

RSpec.describe Organized::ParkingNotificationsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/parking_notifications" }
  include_context :request_spec_logged_in_as_organization_member

  let(:current_organization) { FactoryBot.create(:organization_with_paid_features, paid_feature_slugs: paid_feature_slugs) }
  let(:bike) { FactoryBot.create(:bike) }
  let(:paid_feature_slugs) { ["abandoned_bikes"] }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
    context "json" do
      it "returns empty" do
        get base_url, params: { format: :json }
        expect(response.status).to eq(200)
        expect(json_result).to eq("parking_notifications" => [])
        expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
        expect(response.headers["Access-Control-Request-Method"]).not_to be_present
      end
      context "with an impound_record" do
        let(:impound_record) { FactoryBot.create(:impound_record) }
        let!(:parking_notification1) do
          FactoryBot.create(:parking_notification_organized,
                            organization: current_organization,
                            bike: bike,
                            created_at: Time.current - 1.hour,
                            impound_record: impound_record)
        end
        let(:target) do
          {
            id: parking_notification1.id,
            kind: "appears_abandoned",
            kind_humanized: "Appears forgotten",
            created_at: parking_notification1.created_at.to_i,
            lat: parking_notification1.latitude,
            lng: parking_notification1.longitude,
            user_id: parking_notification1.user_id,
            impound_record_id: impound_record.id,
            impound_record_at: impound_record.created_at.to_i,
            bike: {
              id: bike.id,
              title: bike.title_string,
            },
          }
        end
        it "renders json, no cors present" do
          get base_url, params: { format: :json }
          expect(response.status).to eq(200)
          parking_notifications = json_result["parking_notifications"]
          expect(parking_notifications.count).to eq 1
          expect(parking_notifications.first).to eq target.as_json
          expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
          expect(response.headers["Access-Control-Request-Method"]).not_to be_present
        end
      end
    end
    context "with searched bike" do
      let!(:parking_notification1) { FactoryBot.create(:parking_notification, organization: current_organization) }
      let(:parking_notification2) { FactoryBot.create(:parking_notification, organization: current_organization) }
      let(:bike) { parking_notification2.bike }
      it "renders" do
        get base_url, params: { search_bike_id: bike.id }, headers: json_headers
        expect(response.status).to eq(200)
        expect(json_result["parking_notifications"].count).to eq 1
        expect(json_result["parking_notifications"].first.dig("bike", "id")).to eq bike.id
      end
    end
  end

  describe "show" do
    let(:parking_notification) { FactoryBot.create(:parking_notification, organization: current_organization) }
    it "renders" do
      get "#{base_url}/#{parking_notification.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template :show
    end
  end

  describe "create" do
    let(:parking_notification_params) do
      {
        kind: "parked_incorrectly",
        notes: "some details about the abandoned thing",
        bike_id: bike.to_param,
        latitude: default_location[:latitude],
        longitude: default_location[:longitude],
        accuracy: 12,
      }
    end

    context "geolocated" do
      before do
        FactoryBot.create(:state_new_york)
      end

      it "creates" do
        expect(current_organization.paid_for?("abandoned_bikes")).to be_truthy
        expect do
          post base_url, params: {
            organization_id: current_organization.to_param,
            parking_notification: parking_notification_params,
          }
          expect(response).to redirect_to organization_parking_notifications_path(organization_id: current_organization.to_param)
          expect(flash[:success]).to be_present
        end.to change(ParkingNotification, :count).by(1)
        parking_notification = ParkingNotification.last

        expect(parking_notification.user).to eq current_user
        expect(parking_notification.organization).to eq current_organization
        expect(parking_notification.bike).to eq bike
        expect(parking_notification.notes).to eq parking_notification_params[:notes]
        expect(parking_notification.latitude).to eq parking_notification_params[:latitude]
        expect(parking_notification.longitude).to eq parking_notification_params[:longitude]
        # TODO: location refactor
        # expect(parking_notification.address).to eq default_location[:formatted_address]
        expect(parking_notification.accuracy).to eq 12
      end

      context "user without organization membership" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "does not create" do
          expect(current_organization.paid_for?("abandoned_bikes")).to be_truthy
          expect do
            post base_url, params: {
              organization_id: current_organization.to_param,
              parking_notification: parking_notification_params,
            }
            expect(response).to redirect_to user_root_url
            expect(flash[:error]).to be_present
          end.to_not change(ParkingNotification, :count)
        end
      end

      context "without a required param" do
        it "fails and renders error" do
          expect do
            post base_url, params: {
              organization_id: current_organization.to_param,
              parking_notification: parking_notification_params.except(:latitude),
            }
            expect(flash[:error]).to match(/address/i)
          end.to_not change(ParkingNotification, :count)
        end
      end

      context "organization without abandoned_bikes" do
        let(:paid_feature_slugs) { [] }

        it "does not create" do
          current_organization.reload
          invoice = current_organization.current_invoices.first
          expect(invoice.paid_in_full?).to be_truthy
          expect(current_organization.is_paid).to be_truthy
          expect(current_organization.paid_for?("abandoned_bikes")).to be_falsey
          expect do
            post base_url, params: {
              organization_id: current_organization.to_param, parking_notification: parking_notification_params
            }
            expect(response).to redirect_to organization_bikes_path(organization_id: current_organization.to_param)
            expect(flash[:error]).to be_present
          end.to_not change(ParkingNotification, :count)
        end
      end
    end
  end
end
