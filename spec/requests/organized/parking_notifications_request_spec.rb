require "rails_helper"

RSpec.describe Organized::ParkingNotificationsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/parking_notifications" }
  include_context :request_spec_logged_in_as_organization_member

  let(:current_organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: enabled_feature_slugs) }
  let(:bike) { FactoryBot.create(:bike) }
  let(:enabled_feature_slugs) { ["parking_notifications"] }

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
            kind_humanized: "Appears abandoned",
            created_at: parking_notification1.created_at.to_i,
            lat: parking_notification1.latitude,
            lng: parking_notification1.longitude,
            user_id: parking_notification1.user_id,
            user_display_name: parking_notification1.user.display_name,
            impound_record_id: impound_record.id,
            impound_record_at: impound_record.created_at.to_i,
            unregistered_bike: false,
            notification_number: 1,
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

  describe "email" do
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
        internal_notes: "some details about the abandoned thing",
        bike_id: bike.to_param,
        use_entered_address: "false",
        latitude: default_location[:latitude],
        longitude: default_location[:longitude],
        message: "Some message to the user",
        accuracy: 12.0,
      }
    end

    context "geolocated" do
      context "user without organization membership" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "does not create" do
          expect(current_organization.enabled?("parking_notifications")).to be_truthy
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

      context "organization without parking_notifications" do
        let(:enabled_feature_slugs) { [] }

        it "does not create" do
          current_organization.reload
          invoice = current_organization.current_invoices.first
          expect(invoice.paid_in_full?).to be_truthy
          expect(current_organization.is_paid).to be_truthy
          expect(current_organization.enabled?("parking_notifications")).to be_falsey
          expect do
            post base_url, params: {
              organization_id: current_organization.to_param, parking_notification: parking_notification_params
            }
            expect(response).to redirect_to organization_bikes_path(organization_id: current_organization.to_param)
            expect(flash[:error]).to be_present
          end.to_not change(ParkingNotification, :count)
        end
      end

      it "creates" do
        Sidekiq::Testing.inline! do
          FactoryBot.create(:state_new_york)
          expect(current_organization.enabled?("parking_notifications")).to be_truthy
          ActionMailer::Base.deliveries = []
          expect do
            post base_url, params: {
              organization_id: current_organization.to_param,
              parking_notification: parking_notification_params,
            }
            expect(response).to redirect_to organization_parking_notifications_path(organization_id: current_organization.to_param)
            expect(flash[:success]).to be_present
          end.to change(ParkingNotification, :count).by(1)
          parking_notification = ParkingNotification.last

          expect_attrs_to_match_hash(parking_notification, parking_notification_params.except(:use_entered_address))
          expect(parking_notification.user).to eq current_user
          expect(parking_notification.organization).to eq current_organization
          expect(parking_notification.address).to eq default_location[:formatted_address_no_country]
          expect(parking_notification.location_from_address).to be_falsey

          expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          expect(parking_notification.delivery_status).to be_present
        end
      end

      context "manual address and repeat" do
        let(:state) { FactoryBot.create(:state, name: "California", abbreviation: "CA") }
        let!(:parking_notification_initial) { FactoryBot.create(:parking_notification, bike: bike, organization: current_organization, created_at: Time.current - 1.year, state: state) }
        let(:repeat_params) do
          parking_notification_params.merge(is_repeat: true,
                                            use_entered_address: "true",
                                            street: "300 Lakeside Dr",
                                            city: "Oakland",
                                            zipcode: "94612",
                                            state_id: state.id.to_s,
                                            country_id: Country.united_states.id)
        end
        include_context :geocoder_real
        it "creates", vcr: true do
          Sidekiq::Worker.clear_all
          expect do
            post base_url, params: {
              organization_id: current_organization.to_param,
              parking_notification: repeat_params,
            }
            expect(response).to redirect_to organization_parking_notifications_path(organization_id: current_organization.to_param)
            expect(flash[:success]).to be_present
          end.to change(ParkingNotification, :count).by(1)
          expect(EmailParkingNotificationWorker.jobs.count).to eq 1
          parking_notification = ParkingNotification.last

          expect_attrs_to_match_hash(parking_notification, repeat_params.except(:use_entered_address, :is_repeat, :latitude, :longitude))
          expect(parking_notification.user).to eq current_user
          expect(parking_notification.organization).to eq current_organization
          expect(parking_notification.initial_record).to eq parking_notification_initial
          expect(parking_notification.latitude).to eq(37.8087498)
          expect(parking_notification.longitude).to eq(-122.263705)
          expect(parking_notification.location_from_address).to be_truthy
        end
      end
    end
  end
end
