require "rails_helper"

RSpec.describe Organized::AbandonedRecordsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/abandoned_records" }
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
        expect(json_result).to eq("abandoned_records" => [])
        expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
        expect(response.headers["Access-Control-Request-Method"]).not_to be_present
      end
      context "with an impound_record" do
        let(:impound_record) { FactoryBot.create(:impound_record) }
        let!(:abandoned_record1) do
          FactoryBot.create(:abandoned_record_organized,
                            organization: current_organization,
                            bike: bike,
                            created_at: Time.current - 1.hour,
                            impound_record: impound_record)
        end
        let(:target) do
          {
            id: abandoned_record1.id,
            kind: "appears_forgotten",
            kind_humanized: "Appears forgotten",
            created_at: abandoned_record1.created_at.to_i,
            lat: abandoned_record1.latitude,
            lng: abandoned_record1.longitude,
            user_id: abandoned_record1.user_id,
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
          abandoned_records = json_result["abandoned_records"]
          expect(abandoned_records.count).to eq 1
          expect(abandoned_records.first).to eq target.as_json
          expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
          expect(response.headers["Access-Control-Request-Method"]).not_to be_present
        end
      end
    end
    context "with searched bike" do
      let!(:abandoned_record1) { FactoryBot.create(:abandoned_record, organization: current_organization) }
      let(:abandoned_record2) { FactoryBot.create(:abandoned_record, organization: current_organization) }
      let(:bike) { abandoned_record2.bike }
      it "renders" do
        get base_url, params: { search_bike_id: bike.id }, headers: json_headers
        expect(response.status).to eq(200)
        expect(json_result["abandoned_records"].count).to eq 1
        expect(json_result["abandoned_records"].first.dig("bike", "id")).to eq bike.id
      end
    end
  end

  describe "show" do
    let(:abandoned_record) { FactoryBot.create(:abandoned_record, organization: current_organization) }
    it "renders" do
      get "#{base_url}/#{abandoned_record.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template :show
    end
  end

  describe "create" do
    let(:abandoned_record_params) do
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
            abandoned_record: abandoned_record_params,
          }
          expect(response).to redirect_to organization_abandoned_records_path(organization_id: current_organization.to_param)
          expect(flash[:success]).to be_present
        end.to change(AbandonedRecord, :count).by(1)
        abandoned_record = AbandonedRecord.last

        expect(abandoned_record.user).to eq current_user
        expect(abandoned_record.organization).to eq current_organization
        expect(abandoned_record.bike).to eq bike
        expect(abandoned_record.notes).to eq abandoned_record_params[:notes]
        expect(abandoned_record.latitude).to eq abandoned_record_params[:latitude]
        expect(abandoned_record.longitude).to eq abandoned_record_params[:longitude]
        # TODO: location refactor
        # expect(abandoned_record.address).to eq default_location[:formatted_address]
        expect(abandoned_record.accuracy).to eq 12
      end

      context "user without organization membership" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "does not create" do
          expect(current_organization.paid_for?("abandoned_bikes")).to be_truthy
          expect do
            post base_url, params: {
              organization_id: current_organization.to_param,
              abandoned_record: abandoned_record_params,
            }
            expect(response).to redirect_to user_root_url
            expect(flash[:error]).to be_present
          end.to_not change(AbandonedRecord, :count)
        end
      end

      context "without a required param" do
        it "fails and renders error" do
          expect do
            post base_url, params: {
              organization_id: current_organization.to_param,
              abandoned_record: abandoned_record_params.except(:latitude),
            }
            expect(flash[:error]).to match(/address/i)
          end.to_not change(AbandonedRecord, :count)
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
              organization_id: current_organization.to_param, abandoned_record: abandoned_record_params
            }
            expect(response).to redirect_to organization_bikes_path(organization_id: current_organization.to_param)
            expect(flash[:error]).to be_present
          end.to_not change(AbandonedRecord, :count)
        end
      end
    end
  end
end
