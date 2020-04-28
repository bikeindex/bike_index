require "rails_helper"

RSpec.describe Organized::BikesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/bikes" }
  include_context :request_spec_logged_in_as_organization_member

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response.status).to eq(200)
      expect(assigns(:unregistered_parking_notification)).to be_falsey
      expect(response).to render_template(:new)
    end
    context "parking_notification" do
      it "renders with unregistered_parking_notification" do
        get "#{base_url}/new", params: { parking_notification: 1 }
        expect(response.status).to eq(200)
        expect(assigns(:unregistered_parking_notification)).to be_falsey
        expect(response).to render_template(:new)
      end
      context "with feature" do
        let(:current_organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["parking_notifications"]) }
        it "renders with unregistered_parking_notification" do
          get "#{base_url}/new", params: { parking_notification: 1 }
          expect(response.status).to eq(200)
          expect(assigns(:unregistered_parking_notification)).to be_truthy
          expect(response).to render_template(:new)
        end
      end
    end
  end

  describe "new_iframe" do
    it "renders" do
      get "#{base_url}/new_iframe", params: { parking_notification: 1 }
      expect(response.status).to eq(200)
      expect(response).to render_template(:new_iframe)
    end
    context "without current_organization" do
      include_context :request_spec_logged_in_as_user
      it "redirects (unlike normal iframe)" do
        expect(current_user.organizations).to eq([])
        get "#{base_url}/new_iframe", params: { parking_notification: 1 }
        expect(response).to redirect_to user_root_url
        expect(flash[:error]).to be_present
      end
    end
  end

  describe "create" do
    before { current_organization.update_attributes(auto_user: auto_user) }
    let(:auto_user) { current_user }
    let(:b_param) { BParam.create(creator_id: current_organization.auto_user.id, params: { creation_organization_id: current_organization.id, embeded: true }) }
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    let(:color) { FactoryBot.create(:color, name: "black") }
    let!(:state) { FactoryBot.create(:state_new_york) }
    let(:testable_bike_params) { bike_params.except(:serial_unknown, :b_param_id_token, :cycle_type_slug, :accuracy, :origin) }

    context "with parking_notification" do
      let(:current_organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }
      let(:state) { FactoryBot.create(:state, name: "New York", abbreviation: "NY") }

      let(:parking_notification) do
        {
          kind: "parked_incorrectly_notification",
          internal_notes: "some details about the abandoned thing",
          use_entered_address: "false",
          latitude: default_location[:latitude],
          longitude: default_location[:longitude],
          message: "Some message to the user",
          street: "",
          city: "",
          accuracy: "14.2",
          zipcode: "10007",
          state_id: state.id.to_s,
          country_id: Country.united_states.id,
        }
      end
      let(:bike_params) do
        {
          serial_number: "",
          b_param_id_token: b_param.id_token,
          cycle_type_slug: " Tricycle ",
          manufacturer_id: manufacturer.id,
          primary_frame_color_id: color.id,
          latitude: default_location[:latitude],
          longitude: default_location[:longitude],
        }
      end

      it "creates along with parking_notification" do
        current_organization.reload
        expect(current_organization.auto_user).to eq current_user
        ActionMailer::Base.deliveries = []
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! do
          expect do
            post base_url, params: { bike: bike_params, parking_notification: parking_notification }
            expect(flash[:success]).to match(/tricycle/i)
            expect(response).to redirect_to new_iframe_organization_bikes_path(organization_id: current_organization.to_param)
          end.to change(Ownership, :count).by 1
          expect(ActionMailer::Base.deliveries.count).to eq 0
        end

        b_param.reload
        expect(b_param.creation_organization).to eq current_organization
        expect(b_param.unregistered_parking_notification?).to be_truthy
        expect(b_param.origin).to eq "organization_form"

        bike = Bike.unscoped.find(b_param.created_bike_id)
        expect(bike.made_without_serial?).to be_falsey
        expect(bike.serial_unknown?).to be_truthy
        expect(bike.cycle_type).to eq "tricycle"
        expect(bike.creation_organization).to eq current_organization
        expect(bike.status).to eq "unregistered_parking_notification"

        testable_bike_params.except(:serial_number).each do |k, v|
          pp k unless bike.send(k).to_s == v.to_s
          expect(bike.send(k).to_s).to eq v.to_s
        end

        ownership = bike.ownerships.first
        expect(ownership.send_email).to be_falsey
        expect(ownership.owner_email).to eq auto_user.email

        creation_state = bike.creation_state
        expect(creation_state.organization).to eq current_organization
        expect(creation_state.creator).to eq bike.creator
        expect(creation_state.origin).to eq "organization_form"

        expect(bike.parking_notifications.count).to eq 1
        parking_notification = bike.parking_notifications.first
        expect(parking_notification.organization).to eq current_organization
        expect(parking_notification.kind).to eq "parked_incorrectly_notification"
        expect(parking_notification.internal_notes).to eq "some details about the abandoned thing"
        expect(parking_notification.message).to eq "Some message to the user"
        expect(parking_notification.latitude).to eq default_location[:latitude]
        expect(parking_notification.longitude).to eq default_location[:longitude]
        expect(parking_notification.location_from_address).to be_falsey
        expect(parking_notification.street).to eq "278 Broadway"
        expect(parking_notification.city).to eq "New York"
        expect(parking_notification.accuracy).to eq 14.2
        expect(parking_notification.retrieval_link_token).to be_blank
      end

      context "different auto_user, impound_notification" do
        let!(:auto_user) { FactoryBot.create(:organization_member, organization: current_organization) }
        let(:parking_notification_abandoned) do
          parking_notification.merge(use_entered_address: "1",
                                     kind: "impound_notification",
                                     street: "278 Broadway",
                                     city: "New York",
                                     internal_notes: "Impounded it!")
        end
        it "creates a new ownership and bike from an organization, parking_notification, impound_record" do
          current_organization.reload
          expect(current_organization.auto_user).to eq auto_user

          Sidekiq::Testing.inline! do
            ActionMailer::Base.deliveries = []
            expect do
              post base_url, params: { bike: bike_params, parking_notification: parking_notification_abandoned }
              expect(flash[:success]).to match(/tricycle/i)
              expect(response).to redirect_to new_iframe_organization_bikes_path(organization_id: current_organization.to_param)
            end.to change(Ownership, :count).by 1
            expect(ActionMailer::Base.deliveries.count).to eq 0
          end

          b_param.reload
          expect(b_param.creation_organization).to eq current_organization
          expect(b_param.unregistered_parking_notification?).to be_truthy
          expect(b_param.origin).to eq "organization_form"

          bike = Bike.unscoped.find(b_param.created_bike_id)
          expect(bike.made_without_serial?).to be_falsey
          expect(bike.serial_unknown?).to be_truthy
          expect(bike.cycle_type).to eq "tricycle"
          expect(bike.creation_organization).to eq current_organization
          expect(bike.status).to eq "unregistered_parking_notification"

          testable_bike_params.except(:serial_number).each do |k, v|
            pp k unless bike.send(k).to_s == v.to_s
            expect(bike.send(k).to_s).to eq v.to_s
          end

          ownership = bike.ownerships.first
          expect(ownership.send_email).to be_falsey
          # Maybe make this work?
          # expect(ownership.claimed?).to be_truthy
          expect(ownership.owner_email).to eq auto_user.email

          creation_state = bike.creation_state
          expect(creation_state.organization).to eq current_organization
          expect(creation_state.creator).to eq bike.creator
          expect(creation_state.origin).to eq "organization_form"

          expect(ParkingNotification.where(bike_id: bike.id).count).to eq 1
          parking_notification = ParkingNotification.where(bike_id: bike.id).first
          expect(bike.parking_notifications.count).to eq 1
          parking_notification = bike.parking_notifications.first
          expect(parking_notification.organization).to eq current_organization
          expect(parking_notification.kind).to eq "impound_notification"
          expect(parking_notification.internal_notes).to eq "Impounded it!"
          expect(parking_notification.message).to eq "Some message to the user"
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.impounded?).to be_truthy
          expect(parking_notification.latitude).to eq default_location[:latitude]
          expect(parking_notification.longitude).to eq default_location[:longitude]
          expect(parking_notification.location_from_address).to be_truthy
          expect(parking_notification.street).to eq "278 Broadway"
          expect(parking_notification.city).to eq "New York"

          impound_record = bike.current_impound_record
          expect(impound_record.parking_notification).to eq parking_notification
          expect(impound_record.organization).to eq current_organization
          expect(impound_record.current?).to be_truthy
        end
      end
    end
  end
end
