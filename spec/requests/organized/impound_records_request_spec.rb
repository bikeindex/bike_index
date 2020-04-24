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
    let(:kind) { "note" }
    let(:update_params) { { notes: "OK boomer", kind: kind } }
    let(:ownership_original) { FactoryBot.create(:ownership, bike: bike) }
    before do
      expect(ownership_original).to be_present
      expect(impound_record).to be_present
      ImpoundUpdateBikeWorker.new.perform(impound_record.id)
      ActionMailer::Base.deliveries = []
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.inline!
    end
    after { Sidekiq::Testing.fake! }
    it "updates" do
      expect do
        put "#{base_url}/#{impound_record.id}", params: { impound_record_update: update_params }
      end.to change(ImpoundRecordUpdate, :count).by 1
      expect(ActionMailer::Base.deliveries.count).to eq 0
      impound_record.reload
      expect(impound_record.impound_record_updates.count).to eq 1
      expect(impound_record.current?).to be_truthy
      impound_record_update = impound_record.impound_record_updates.last
      expect(impound_record_update.kind).to eq "note"
      expect(impound_record_update.notes).to eq "OK boomer"
      expect(impound_record_update.user).to eq current_user
      expect(impound_record_update.resolved).to be_truthy
    end
    context "retrieved_by_owner" do
      let(:kind) { "retrieved_by_owner" }
      it "returns to user" do
        bike.reload
        expect(bike.status_impounded?).to be_truthy
        expect do
          put "#{base_url}/#{impound_record.id}", params: { impound_record_update: update_params }
        end.to change(ImpoundRecordUpdate, :count).by 1
        expect(ActionMailer::Base.deliveries.count).to eq 0
        impound_record.reload
        expect(impound_record.impound_record_updates.count).to eq 1
        expect(impound_record.active?).to be_falsey
        expect(impound_record.resolved_at).to be_within(5).of Time.current
        expect(impound_record.status).to eq "retrieved_by_owner"
        impound_record_update = impound_record.impound_record_updates.last
        expect(impound_record.resolving_update).to eq impound_record_update
        expect(impound_record_update.kind).to eq "retrieved_by_owner"
        expect(impound_record_update.notes).to eq "OK boomer"
        expect(impound_record_update.user).to eq current_user
        expect(impound_record_update.resolved).to be_truthy

        bike.reload
        expect(bike.status_with_owner?).to be_truthy
        expect(bike.ownerships.count).to eq 1
      end
    end
    context "removed_from_bike_index" do
      let(:impound_record) { FactoryBot.create(:impound_record, organization: current_organization, bike: bike) }
      let(:kind) { "removed_from_bike_index"}
      it "deletes, updates user on the impound_record" do
        expect(impound_record.user).to_not eq current_user
        expect do
          put "#{base_url}/#{impound_record.id}", params: { impound_record_update: update_params }
        end.to change(ImpoundRecordUpdate, :count).by 1
        expect(ActionMailer::Base.deliveries.count).to eq 0
        impound_record.reload
        expect(impound_record.impound_record_updates.count).to eq 1
        expect(impound_record.active?).to be_falsey
        expect(impound_record.resolved_at).to be_within(5).of Time.current
        expect(impound_record.status).to eq "removed_from_bike_index"
        impound_record_update = impound_record.impound_record_updates.last
        expect(impound_record.resolving_update).to eq impound_record_update
        expect(impound_record_update.kind).to eq "removed_from_bike_index"
        expect(impound_record_update.notes).to eq "OK boomer"
        expect(impound_record_update.user).to eq current_user
        expect(impound_record_update.resolved).to be_truthy

        expect(impound_record.bike.deleted?).to be_truthy
      end
    end
    context "transfered" do
      let(:kind) { "transferred_to_new_owner" }
      let(:update_params_with_email) { update_params.merge(transfer_email: "a@b.c") }
      it "sends to a new owner" do
        bike.reload
        expect(bike.status_impounded?).to be_truthy
        expect do
          put "#{base_url}/#{impound_record.id}", params: { impound_record_update: update_params_with_email }
        end.to change(ImpoundRecordUpdate, :count).by 1
        expect(ActionMailer::Base.deliveries.count).to eq 1
        impound_record.reload
        expect(impound_record.impound_record_updates.count).to eq 1
        expect(impound_record.active?).to be_falsey
        expect(impound_record.resolved_at).to be_within(5).of Time.current
        expect(impound_record.status).to eq "transferred_to_new_owner"
        impound_record_update = impound_record.impound_record_updates.last
        expect(impound_record.resolving_update).to eq impound_record_update
        expect(impound_record_update.kind).to eq "transferred_to_new_owner"
        expect(impound_record_update.notes).to eq "OK boomer"
        expect(impound_record_update.user).to eq current_user
        expect(impound_record_update.resolved).to be_truthy

        bike.reload
        expect(bike.owner_email.owner_email).to eq "a@b.c"
        expect(bike.status_with_owner?).to be_truthy
        expect(bike.ownerships.count).to eq 2
        expect(bike.current_ownership.impound_record).to eq impound_record
        expect(bike.current_ownership.organization).to eq organization
        expect(bike.current_ownership.owner_email).to eq "a@b.c"
      end
      # context "without a transfer_email" do
      #   it "returns with a flash error" do
      #     expect do
      #       put "#{base_url}/#{impound_record.id}", params: { impound_record_update: update_params }
      #     end.to_not change(ImpoundRecordUpdate, :count)
      #     expect(flash[:error]).to be_present
      #     expect(ActionMailer::Base.deliveries.count).to eq 0
      #     impound_record.reload
      #     expect(impound_record.current?).to be_truthy
      #   end
      # end
      # context "unregistered_parking_notification" do
      #   # let(:parking_notification)
      #   it "sends to a new owner, ensures mark user hidden is off" do
      #     # parking_notification.reload
      #     # expect(parking_notification.unregistered_bike).to be_truthy
      #   end
      # end
    end
    # context "with locations" do
    #   let(:kind) { "move_location" }
    #   it "updates, moves to a new location" do
    #     current_organization.reload
    #     expect(current_organization.enabled?("impound_bikes_locations")).to be_truthy
    #     expect(impound_record.location).to eq location
    #     # Moves locations
    #   end
    # end
  end
end
