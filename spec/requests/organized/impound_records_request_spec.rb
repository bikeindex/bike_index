require "rails_helper"

RSpec.describe Organized::ParkingNotificationsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/impound_records" }
  include_context :request_spec_logged_in_as_organization_member

  let(:current_organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: enabled_feature_slugs) }
  let(:bike) { FactoryBot.create(:bike, owner_email: "someemail@things.com") }
  let(:enabled_feature_slugs) { %w[parking_notifications impound_bikes] }
  let(:impound_record) { FactoryBot.create(:impound_record, organization: current_organization, user: current_user, bike: bike) }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:impound_records).count).to eq 0
    end
    context "multiple impound_records" do
      let!(:impound_record2) { FactoryBot.create(:impound_record, organization: current_organization, user: current_user, bike: bike2) }
      let(:bike2) { FactoryBot.create(:bike, serial_number: "yaris") }
      let!(:impound_record_retrieved) { FactoryBot.create(:impound_record_resolved, organization: current_organization, user: current_user, bike: bike, resolved_at: Time.current - 1.week, created_at: Time.current - 1.hour) }
      let!(:impound_record_unorganized) { FactoryBot.create(:impound_record) }
      it "finds by bike searches and also by impound scoping" do
        [impound_record2, impound_record_retrieved, impound_record_unorganized].each do |ir|
          ImpoundUpdateBikeWorker.new.perform(ir.id)
        end
        # Test that impound_record.active.bikes scopes correctly
        expect(current_organization.impound_records.active.pluck(:id)).to eq([impound_record2.id])
        expect(current_organization.impound_records.active.bikes.pluck(:id)).to eq([bike2.id])
        expect(impound_record).to be_present
        ImpoundUpdateBikeWorker.new.perform(impound_record.id)
        expect(current_organization.impound_records.bikes.count).to eq 2
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:search_status)).to eq "active"
        expect(assigns(:impound_records).pluck(:id)).to match_array([impound_record.id, impound_record2.id])

        get "#{base_url}?email=&serial=yar1s"
        expect(response.status).to eq(200)
        expect(assigns(:impound_records).pluck(:id)).to eq([impound_record2.id])

        get "#{base_url}?email=someemail%40things"
        expect(response.status).to eq(200)
        expect(assigns(:impound_records).pluck(:id)).to match_array([impound_record.id])

        get "#{base_url}?email=someemail%40things&search_status=all"
        expect(response.status).to eq(200)
        expect(assigns(:search_status)).to eq "all"
        expect(assigns(:impound_records).pluck(:id)).to match_array([impound_record.id, impound_record_retrieved.id])
      end
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{impound_record.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end
  end

  describe "update" do
    it "updates" do
      # adds a note
    end
    context "with locations" do
      it "updates, moves to a new location" do
        # Moves locations
      end
    end
    context "removed_from_bike_index" do
      let(:kind) { "removed_from_bike_index"}
      it "deletes" do

      end
    end
    context "transfered" do
      let(:kind) { "transfered"}
      it "sends to a new owner" do
        # is sold, etc
      end
      context "unregistered_parking_notification" do
        # let(:parking_notification)
        it "sends to a new owner, ensures mark user hidden is off" do
          # parking_notification.reload
          # expect(parking_notification.unregistered_bike).to be_truthy
        end
      end
    end
  end
end
