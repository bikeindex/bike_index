require "rails_helper"

RSpec.describe Organized::BikesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/bikes" }
  include_context :request_spec_logged_in_as_organization_member

  describe "create" do
    before { current_organization.update_attributes(auto_user: auto_user) }
    let(:auto_user) { current_user }
    let(:b_param) { BParam.create(creator_id: current_organization.auto_user.id, params: { creation_organization_id: current_organization.id, embeded: true }) }
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    let(:color) { FactoryBot.create(:color, name: "black") }
    let(:testable_bike_params) { bike_params.except(:serial_unknown, :b_param_id_token, :cycle_type_slug, :accuracy, :origin) }

    context "abandoned_bikes" do
      context "with paid_feature" do
        let(:current_organization) { FactoryBot.create(:organization_with_paid_features, paid_feature_slugs: ["abandoned_bikes"]) }

        let(:bike_params) do
          {
            serial_number: "",
            b_param_id_token: b_param.id_token,
            cycle_type_slug: " Tricycle ",
            origin: "organization_form",
            state: "abandoned",
            manufacturer_id: manufacturer.id,
            primary_frame_color_id: color.id,
            latitude: default_location[:latitude],
            longitude: default_location[:longitude],
            address: "",
            accuracy: "12",
          }
        end
        context "different auto_user" do
          let(:auto_user) { FactoryBot.create(:organization_member, organization: current_organization) }
          it "creates a new ownership and bike from an organization" do
            current_organization.reload
            expect(current_organization.auto_user).to_not eq current_user

            expect do
              post base_url, params: { bike: bike_params }
              expect(flash[:success]).to match(/tricycle/i)
              expect(response).to redirect_to new_iframe_organization_bikes_path(organization_id: current_organization.to_param)
            end.to change(Ownership, :count).by 1

            bike = Bike.last
            expect(bike.made_without_serial?).to be_falsey
            expect(bike.serial_unknown?).to be_truthy
            expect(bike.cycle_type).to eq "tricycle"

            testable_bike_params.except(:address).each do |k, v|
              pp k unless bike.send(k).to_s == v.to_s
              expect(bike.send(k).to_s).to eq v.to_s
            end

            ownership = bike.ownerships.first
            expect(ownership.send_email).to be_falsey
            expect(ownership.claimed?).to be_truthy
            expect(ownership.owner_email).to eq auto_user.email

            creation_state = bike.creation_state
            expect(creation_state.origin).to eq "embed"
            expect(creation_state.organization).to eq organization
            expect(creation_state.creator).to eq bike.creator
            expect(creation_state.state).to eq "state_abandoned"
            expect(creation_state.origin).to eq "organization_form"

            expect(bike.abandoned_records.count).to eq 1
            abandoned_record = bike.abandoned_records.first
            expect(abandoned_record.organization).to eq current_organization
            expect(abandoned_record.latitude).to eq default[:latitude]
            expect(abandoned_record.longitude).to eq default[:longitude]
            expect(abandoned_record.address).to eq default_location[:formatted_address]
            expect(abandoned_record.accuracy).to eq 12
          end
        end
      end
    end
  end
end
