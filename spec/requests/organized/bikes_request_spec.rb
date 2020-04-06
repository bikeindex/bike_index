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
  end

  describe "create" do
    before { current_organization.update_attributes(auto_user: auto_user) }
    let(:auto_user) { current_user }
    let(:b_param) { BParam.create(creator_id: current_organization.auto_user.id, params: { creation_organization_id: current_organization.id, embeded: true }) }
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    let(:color) { FactoryBot.create(:color, name: "black") }
    let!(:state) { FactoryBot.create(:state_new_york) }
    let(:testable_bike_params) { bike_params.except(:serial_unknown, :b_param_id_token, :cycle_type_slug, :accuracy, :origin) }

    context "abandoned_bikes" do
      it "creates b_param, redirects, but does not register"

      context "with paid_feature" do
        let(:current_organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["parking_notifications"]) }

        let(:bike_params) do
          {
            serial_number: "",
            b_param_id_token: b_param.id_token,
            cycle_type_slug: " Tricycle ",
            status: "status_abandoned",
            manufacturer_id: manufacturer.id,
            primary_frame_color_id: color.id,
            latitude: default_location[:latitude],
            longitude: default_location[:longitude],
            accuracy: "12",
          }
        end
        context "different auto_user" do
          let!(:auto_user) { FactoryBot.create(:organization_member, organization: current_organization) }
          xit "creates a new ownership and bike from an organization" do
            current_organization.reload
            expect(current_organization.auto_user).to eq auto_user

            Sidekiq::Testing.inline! do
              expect do
                post base_url, params: { bike: bike_params }
                expect(flash[:success]).to match(/tricycle/i)
                expect(response).to redirect_to new_iframe_organization_bikes_path(organization_id: current_organization.to_param)
              end.to change(Ownership, :count).by 1
            end

            b_param.reload
            expect(b_param.creation_organization).to eq current_organization
            expect(b_param.status).to eq "status_abandoned"
            expect(b_param.origin).to eq "organization_form"

            bike = Bike.last
            expect(bike.made_without_serial?).to be_falsey
            expect(bike.serial_unknown?).to be_truthy
            expect(bike.cycle_type).to eq "tricycle"
            expect(bike.creation_organization).to eq current_organization

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
            expect(creation_state.status).to eq "status_abandoned"
            expect(creation_state.origin).to eq "organization_form"

            expect(bike.parking_notifications.count).to eq 1
            parking_notification = bike.parking_notifications.first
            expect(parking_notification.organization).to eq current_organization
            expect(parking_notification.latitude).to eq default_location[:latitude]
            expect(parking_notification.longitude).to eq default_location[:longitude]
            # TODO: location refactor
            # expect(parking_notification.address).to eq default_location[:formatted_address]
            expect(parking_notification.accuracy).to eq 12
          end
        end
      end
    end
  end
end
