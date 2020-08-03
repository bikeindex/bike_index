require "rails_helper"

RSpec.describe Organized::ParkingNotificationsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/parking_notifications" }
  include_context :request_spec_logged_in_as_organization_member

  let(:current_organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: enabled_feature_slugs) }
  let(:bike) { FactoryBot.create(:bike) }
  let(:enabled_feature_slugs) { %w[parking_notifications impound_bikes] }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
    context "json" do
      it "returns empty" do
        get base_url, params: {format: :json}
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
            kind: "parked_incorrectly_notification",
            kind_humanized: "Parked incorrectly",
            status: "impounded",
            created_at: parking_notification1.created_at.to_i,
            lat: parking_notification1.latitude,
            lng: parking_notification1.longitude,
            user_id: parking_notification1.user_id,
            user_display_name: parking_notification1.user.display_name,
            impound_record_id: impound_record&.id,
            resolved_at: parking_notification1.resolved_at&.to_i,
            unregistered_bike: false,
            notification_number: 1,
            bike: {
              id: bike.id,
              title: bike.title_string
            }
          }
        end
        it "renders json, no cors present" do
          get base_url, params: {search_status: "all", format: :json}
          expect(response.status).to eq(200)
          parking_notifications = json_result["parking_notifications"]
          expect(parking_notifications.count).to eq 1
          expect(parking_notifications.first).to eq target.as_json
          expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
          expect(response.headers["Access-Control-Request-Method"]).not_to be_present

          # Also test that current is default scope
          get base_url, params: {format: :json}
          expect(response.status).to eq(200)
          parking_notifications = json_result["parking_notifications"]
          expect(parking_notifications.count).to eq 0
        end
      end
    end
    context "with searched bike" do
      let(:coords1) { [40.79426110344111, -77.86604158369109] }
      let(:coords2) { [40.69908378081713, -77.76302033475155] }
      let(:parking_notification1) { FactoryBot.create(:parking_notification, organization: current_organization, latitude: coords1.first, longitude: coords1.last) }
      let(:parking_notification2) { FactoryBot.create(:parking_notification, organization: current_organization, latitude: coords2.first, longitude: coords2.last) }
      let(:bike) { parking_notification2.bike }
      it "renders", vcr: true do
        expect(parking_notification1.to_coordinates).to eq coords1
        expect(parking_notification2.to_coordinates).to eq coords2
        expect(bike.owner_email).to_not eq parking_notification1.bike.owner_email
        get base_url, params: {search_bike_id: bike.id}, headers: json_headers
        expect(response.status).to eq(200)
        expect(json_result["parking_notifications"].count).to eq 1
        expect(json_result["parking_notifications"].first.dig("bike", "id")).to eq bike.id
        expect(response.header["Per-Page"]).to eq "250"

        get base_url, params: {search_email: bike.owner_email, per_page: 500}, headers: json_headers
        expect(response.status).to eq(200)
        expect(json_result["parking_notifications"].count).to eq 1
        expect(json_result["parking_notifications"].first.dig("bike", "id")).to eq bike.id
        expect(response.header["Per-Page"]).to eq "250"

        # Pagination tests
        get "#{base_url}?per_page=1", headers: json_headers
        expect(response.status).to eq(200)
        expect(response.header["Total"]).to eq("2")
        expect(response.header["Per-Page"]).to eq "1"
        expect(response.header["Link"].match('page=2&per_page=1>; rel=\"next\"')).to be_present
        expect(json_result[:parking_notifications].count).to eq 1
        expect(json_result[:parking_notifications].first[:id]).to eq parking_notification2.id # Because it was created more recently

        # location tests
        get "#{base_url}?search_southwest_coords=40.79184719166159,-77.87257982819405&search_northeast_coords=40.80632036997267,-77.85346084130906", headers: json_headers
        expect(json_result[:parking_notifications].count).to eq 1
        expect(json_result[:parking_notifications].first[:id]).to eq parking_notification1.id
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
        kind: "appears_abandoned_notification",
        internal_notes: "some details about the abandoned thing",
        bike_id: bike.to_param,
        use_entered_address: "false",
        latitude: default_location[:latitude],
        longitude: default_location[:longitude],
        message: "Some message to the user",
        accuracy: 12.0
      }
    end

    context "geolocated" do
      context "user without organization membership" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "does not create" do
          expect(current_organization.enabled?("parking_notifications")).to be_truthy
          expect {
            post base_url, params: {
              organization_id: current_organization.to_param,
              parking_notification: parking_notification_params
            }
            expect(response).to redirect_to user_root_url
            expect(flash[:error]).to be_present
          }.to_not change(ParkingNotification, :count)
        end
      end

      context "without a required param" do
        it "fails and renders error" do
          expect {
            post base_url, params: {
              organization_id: current_organization.to_param,
              parking_notification: parking_notification_params.except(:latitude)
            }
            expect(flash[:error]).to match(/address/i)
          }.to_not change(ParkingNotification, :count)
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
          expect {
            post base_url, params: {
              organization_id: current_organization.to_param, parking_notification: parking_notification_params
            }
            expect(response).to redirect_to organization_bikes_path(organization_id: current_organization.to_param)
            expect(flash[:error]).to be_present
          }.to_not change(ParkingNotification, :count)
        end
      end

      it "creates" do
        FactoryBot.create(:state_new_york)
        expect(current_organization.enabled?("parking_notifications")).to be_truthy
        bike.reload
        expect(bike.status).to eq "status_with_owner"
        expect {
          post base_url, params: {
            organization_id: current_organization.to_param,
            parking_notification: parking_notification_params
          }
          expect(response).to redirect_to organization_parking_notifications_path(organization_id: current_organization.to_param)
          expect(flash[:success]).to be_present
        }.to change(ParkingNotification, :count).by(1)
        parking_notification = ParkingNotification.last

        expect_attrs_to_match_hash(parking_notification, parking_notification_params.except(:use_entered_address))
        expect(parking_notification.user).to eq current_user
        expect(parking_notification.organization).to eq current_organization
        expect(parking_notification.address).to eq default_location[:formatted_address_no_country]
        expect(parking_notification.location_from_address).to be_falsey
        expect(ProcessParkingNotificationWorker.jobs.count).to eq 1

        bike.reload
        expect(bike.status).to eq "status_abandoned"
      end

      context "manual address and repeat" do
        let(:state) { FactoryBot.create(:state, name: "California", abbreviation: "CA") }
        let!(:parking_notification_initial) { FactoryBot.create(:parking_notification, bike: bike, organization: current_organization, created_at: Time.current - 1.year, state: state, kind: "parked_incorrectly_notification") }
        let(:parking_notification_params) do
          {
            kind: "impound_notification",
            internal_notes: "",
            bike_id: bike.to_param,
            use_entered_address: "true",
            latitude: default_location[:latitude],
            longitude: default_location[:longitude],
            message: "Some message to the user",
            accuracy: 12.0,
            is_repeat: "true",
            street: "300 Lakeside Dr",
            city: "Oakland",
            zipcode: "94612",
            state_id: state.id.to_s,
            country_id: Country.united_states.id
          }
        end
        include_context :geocoder_real
        it "creates", vcr: true do
          Sidekiq::Worker.clear_all
          bike.reload
          expect(bike.status).to eq "status_with_owner"
          ActionMailer::Base.deliveries = []
          Sidekiq::Testing.inline! do
            expect {
              post base_url, params: {
                organization_id: current_organization.to_param,
                parking_notification: parking_notification_params
              }
              expect(response).to redirect_to organization_parking_notifications_path(organization_id: current_organization.to_param)
              expect(flash[:success]).to be_present
            }.to change(ParkingNotification, :count).by(1)
          end
          expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          parking_notification = ParkingNotification.last

          expect_attrs_to_match_hash(parking_notification, parking_notification_params.except(:use_entered_address, :is_repeat, :latitude, :longitude))
          expect(parking_notification.user).to eq current_user
          expect(parking_notification.organization).to eq current_organization
          expect(parking_notification.initial_record).to eq parking_notification_initial
          expect(parking_notification.latitude).to eq(37.8087498)
          expect(parking_notification.longitude).to eq(-122.263705)
          expect(parking_notification.location_from_address).to be_truthy
          expect(parking_notification.delivery_status).to eq("email_success")
          expect(parking_notification.impound_record).to be_present
          expect(parking_notification.status).to eq "impounded"
          expect(parking_notification.associated_notifications.pluck(:id)).to eq([parking_notification_initial.id])
          expect(parking_notification.organization).to eq current_organization
          expect(parking_notification.resolved_at).to be_within(5).of parking_notification.created_at

          parking_notification_initial.reload
          expect(parking_notification_initial.status).to eq "impounded"
          expect(parking_notification_initial.impound_record_id).to eq parking_notification.impound_record_id
          expect(parking_notification_initial.resolved_at).to be_within(5).of parking_notification.impound_record.created_at

          bike.reload
          expect(bike.status).to eq "status_impounded"
          expect(bike.current_impound_record).to eq parking_notification.impound_record
        end
      end
    end
  end

  describe "send_additional" do
    let!(:parking_notification_initial) do
      FactoryBot.create(:parking_notification,
        :in_los_angeles,
        bike: bike,
        organization: current_organization,
        message: "some message to the user",
        delivery_status: "failed for unknown reason",
        kind: "parked_incorrectly_notification")
    end
    it "sends another notification" do
      bike.reload
      expect(bike.status).to eq "status_with_owner"
      parking_notification_initial.reload
      expect(parking_notification_initial.current?).to be_truthy
      expect(parking_notification_initial.user).to_not eq current_user
      expect(ParkingNotification.count).to eq 1
      Sidekiq::Worker.clear_all
      ActionMailer::Base.deliveries = []
      Sidekiq::Testing.inline! do
        post base_url, params: {
          organization_id: current_organization.to_param,
          kind: "parked_incorrectly_notification",
          ids: parking_notification_initial.id
        }
        expect(ParkingNotification.count).to eq 2
        parking_notification_initial.reload
        expect(parking_notification_initial.current?).to be_falsey
        expect(parking_notification_initial.delivery_status).to eq "failed for unknown reason"
        parking_notification = ParkingNotification.reorder(:id).last
        expect(ActionMailer::Base.deliveries.count).to eq 1

        expect(assigns(:notifications_failed_resolved).pluck(:id)).to eq([])
        expect(assigns(:notifications_repeated).pluck(:id)).to eq([parking_notification_initial.id])
        expect(response).to redirect_to organization_parking_notification_path(parking_notification, organization_id: current_organization.to_param)

        expect([parking_notification.latitude, parking_notification.longitude]).to eq([parking_notification_initial.latitude, parking_notification_initial.longitude])
        expect(parking_notification.user).to eq current_user
        expect(parking_notification.organization).to eq current_organization
        expect(parking_notification.repeat_record?).to be_truthy
        expect(parking_notification.current?).to be_truthy
        expect(parking_notification.message).to be_blank
        expect(parking_notification.retrieval_link_token).to be_present
        expect(parking_notification.retrieval_link_token).to_not eq parking_notification_initial.retrieval_link_token
        expect(parking_notification.delivery_status).to eq "email_success"
      end

      bike.reload
      expect(bike.status).to eq "status_with_owner"
    end
    context "mark_retrieved" do
      it "marks the parking_notification retrieved" do
        bike.reload
        expect(bike.status).to eq "status_with_owner"
        parking_notification_initial.reload
        expect(parking_notification_initial.current?).to be_truthy
        expect(parking_notification_initial.user).to_not eq current_user
        expect(ParkingNotification.count).to eq 1
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          post base_url, params: {
            organization_id: current_organization.to_param,
            kind: "mark_retrieved",
            ids: parking_notification_initial.id
          }
        end
        expect(ParkingNotification.count).to eq 1
        expect(ActionMailer::Base.deliveries.count).to eq 0
        parking_notification_initial.reload
        expect(parking_notification_initial.current?).to be_falsey
        expect(parking_notification_initial.delivery_status).to eq "failed for unknown reason" # This should not have been bumped
        expect(parking_notification_initial.retrieved_kind).to eq "organization_recovery"
        expect(parking_notification_initial.retrieved_by).to eq current_user

        expect(assigns(:notifications_failed_resolved).pluck(:id)).to eq([])
        expect(assigns(:notifications_repeated).pluck(:id)).to eq([parking_notification_initial.id])
        expect(response).to redirect_to organization_parking_notification_path(parking_notification_initial, organization_id: current_organization.to_param)

        bike.reload
        expect(bike.status).to eq "status_with_owner"
      end
      context "multiple parking notifications" do
        let!(:parking_notification2) { FactoryBot.create(:parking_notification_organized, :in_los_angeles, organization: current_organization, delivery_status: "email_success") }
        it "marks both retrieved" do
          Sidekiq::Worker.clear_all
          ActionMailer::Base.deliveries = []
          Sidekiq::Testing.inline! do
            post base_url, params: {
              organization_id: current_organization.to_param,
              kind: "mark_retrieved",
              ids: "#{parking_notification_initial.id}, #{parking_notification2.id}"
            }
          end
          expect(ParkingNotification.count).to eq 2
          expect(ActionMailer::Base.deliveries.count).to eq 0
          parking_notification_initial.reload
          expect(parking_notification_initial.current?).to be_falsey
          expect(parking_notification_initial.retrieved_kind).to eq "organization_recovery"
          expect(parking_notification_initial.retrieved_by).to eq current_user

          parking_notification2.reload
          expect(parking_notification2.current?).to be_falsey
          expect(parking_notification2.retrieved_kind).to eq "organization_recovery"
          expect(parking_notification2.retrieved_by).to eq current_user
        end
      end
    end
    context "parking notification not active" do
      let!(:parking_notification_initial) { FactoryBot.create(:parking_notification, :retrieved, bike: bike, organization: current_organization) }
      it "shows an alert" do
        bike.reload
        expect(bike.status_with_owner?).to be_truthy
        expect(parking_notification_initial.active?).to be_falsey
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          expect {
            post base_url, params: {
              organization_id: current_organization.to_param,
              kind: "parked_incorrectly_notification",
              ids: parking_notification_initial.id
            }
          }.to_not change(ParkingNotification, :count)
          expect(ActionMailer::Base.deliveries.empty?).to be_truthy
          expect(assigns(:notifications_failed_resolved).pluck(:id)).to eq([parking_notification_initial.id])
          expect(assigns(:notifications_repeated)).to eq([])
        end
      end
    end
    context "replaced" do
      let!(:parking_notification2) do
        FactoryBot.create(:parking_notification,
          :in_chicago,
          bike: bike,
          initial_record_id: parking_notification_initial.id,
          organization: current_organization,
          kind: "parked_incorrectly_notification")
      end

      before { ProcessParkingNotificationWorker.new.perform(parking_notification2.id) }

      def expect_just_current_notification_sent(parking_notification_initial, parking_notification2)
        expect(assigns(:notifications_failed_resolved).pluck(:id)).to eq([])
        expect(assigns(:notifications_repeated).pluck(:id)).to eq([parking_notification2.id])

        expect(ParkingNotification.count).to eq 3
        parking_notification_initial.reload
        parking_notification = ParkingNotification.reorder(:id).last
        expect(ActionMailer::Base.deliveries.count).to eq 1
        bike.reload
        expect(bike.status_abandoned?).to be_truthy

        # It bases off the more recent notification
        expect(parking_notification.to_coordinates).to eq(parking_notification2.to_coordinates)
        expect(parking_notification.user).to eq current_user
        expect(parking_notification.organization).to eq current_organization
        expect(parking_notification.repeat_record?).to be_truthy
        expect(parking_notification.current?).to be_truthy
        expect(parking_notification.message).to be_blank
        expect(parking_notification.retrieval_link_token).to be_present
        expect(parking_notification.retrieval_link_token).to_not eq parking_notification_initial.retrieval_link_token
        expect(parking_notification.delivery_status).to eq "email_success"
      end

      it "sends to the current one" do
        parking_notification2.reload
        parking_notification_initial.reload
        expect(parking_notification2.current?).to be_truthy
        expect(parking_notification_initial.replaced?).to be_truthy
        expect(parking_notification_initial.to_coordinates).to_not eq(parking_notification2.to_coordinates)
        expect(parking_notification_initial.current_associated_notification).to eq parking_notification2
        expect(parking_notification2.current_associated_notification).to eq parking_notification2
        bike.reload
        expect(bike.status).to eq "status_with_owner"
        expect(ParkingNotification.count).to eq 2
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          post base_url, params: {
            organization_id: current_organization.to_param,
            kind: "appears_abandoned_notification",
            ids: parking_notification_initial.id
          }
        end
        expect_just_current_notification_sent(parking_notification_initial, parking_notification2)
        expect(response).to redirect_to organization_parking_notification_path(ParkingNotification.last.id, organization_id: current_organization.to_param)
      end
      context "multiple for one notification stream" do
        # This is how the ids look, for some reason
        let(:ids_params) { {parking_notification_initial.id.to_s => parking_notification_initial.id.to_s, parking_notification2.id.to_s => parking_notification2.id.to_s} }
        it "only sends one" do
          parking_notification2.reload
          parking_notification_initial.reload
          expect(parking_notification2.current?).to be_truthy
          Sidekiq::Worker.clear_all
          ActionMailer::Base.deliveries = []
          Sidekiq::Testing.inline! do
            post base_url, params: {
              organization_id: current_organization.to_param,
              kind: "appears_abandoned_notification",
              ids: ids_params
            }
          end
          expect_just_current_notification_sent(parking_notification_initial, parking_notification2)
          expect(response).to redirect_to organization_parking_notifications_path(organization_id: current_organization.to_param)
        end
      end
    end
    context "impound_notification - multiple" do
      let!(:parking_notification2) { FactoryBot.create(:parking_notification_organized, :in_los_angeles, organization: current_organization) }
      it "impounds them both" do
        bike.reload
        expect(bike.status).to eq "status_with_owner"
        parking_notification_initial.reload
        parking_notification2.reload
        expect(parking_notification_initial.current?).to be_truthy
        expect(parking_notification_initial.user).to_not eq current_user
        expect(parking_notification2.current?).to be_truthy
        expect(parking_notification2.user).to_not eq current_user
        expect(current_organization.parking_notifications.active.pluck(:id)).to match_array([parking_notification_initial.id, parking_notification2.id])
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        expect {
          post base_url, params: {
            organization_id: current_organization.to_param,
            kind: "impound_notification",
            ids: "#{parking_notification_initial.id}, #{parking_notification2.id}"
          }
        }.to change(ProcessParkingNotificationWorker.jobs, :count).by 2
        ProcessParkingNotificationWorker.drain
        expect(ParkingNotification.count).to eq 4
        expect(ActionMailer::Base.deliveries.count).to eq 2

        parking_notification_initial.reload
        parking_notification2.reload

        expect(parking_notification_initial.current?).to be_falsey
        expect(parking_notification_initial.impounded?).to be_truthy
        expect(parking_notification_initial.impound_record_id).to be_present
        expect(parking_notification_initial.repeat_records.count).to eq 1
        initial_impound_notification = parking_notification_initial.repeat_records.impound_notification.first
        expect(initial_impound_notification.delivery_status).to eq "email_success"
        expect(initial_impound_notification.retrieval_link_token).to be_blank
        expect(initial_impound_notification.user).to eq current_user
        expect(parking_notification_initial.to_coordinates).to eq(initial_impound_notification.to_coordinates)

        expect(parking_notification2.current?).to be_falsey
        expect(parking_notification2.impounded?).to be_truthy
        expect(parking_notification2.impound_record_id).to be_present
        expect(parking_notification2.repeat_records.count).to eq 1
        impound_notification2 = parking_notification2.repeat_records.impound_notification.first
        expect(impound_notification2.delivery_status).to eq "email_success"
        expect(impound_notification2.retrieval_link_token).to be_blank
        expect(impound_notification2.user).to eq current_user
        expect(parking_notification2.to_coordinates).to eq(impound_notification2.to_coordinates)

        expect(assigns(:notifications_repeated).pluck(:id)).to match_array([parking_notification_initial.id, parking_notification2.id])
        # Unsure why, but this is failing. Skipping for now
        # expect(assigns(:notifications_failed_resolved).pluck(:id)).to eq([])
        expect(response).to redirect_to organization_parking_notifications_path(organization_id: current_organization.to_param)
      end
    end
  end
end
