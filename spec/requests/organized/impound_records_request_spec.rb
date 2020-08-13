require "rails_helper"

RSpec.describe Organized::ParkingNotificationsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/impound_records" }
  include_context :request_spec_logged_in_as_organization_member

  let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: enabled_feature_slugs) }
  let(:bike) { FactoryBot.create(:bike, owner_email: "someemail@things.com") }
  let(:enabled_feature_slugs) { %w[parking_notifications impound_bikes] }
  let(:impound_record) { FactoryBot.create(:impound_record, organization: current_organization, user: current_user, bike: bike, display_id: 1111) }

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
        expect(assigns(:search_status)).to eq "current"
        expect(assigns(:impound_records).pluck(:id)).to match_array([impound_record.id, impound_record2.id])

        get "#{base_url}?search_email=&serial=yar1s"
        expect(response.status).to eq(200)
        expect(assigns(:impound_records).pluck(:id)).to eq([impound_record2.id])

        get "#{base_url}?search_email=someemail%40things"
        expect(response.status).to eq(200)
        expect(assigns(:impound_records).pluck(:id)).to match_array([impound_record.id])

        get "#{base_url}?search_email=someemail%40things&search_status=all"
        expect(response.status).to eq(200)
        expect(assigns(:search_status)).to eq "all"
        expect(assigns(:impound_records).pluck(:id)).to match_array([impound_record.id, impound_record_retrieved.id])
      end
    end
  end

  describe "show" do
    it "renders" do
      impound_record.reload
      expect(impound_record.display_id).to eq 1111
      get "#{base_url}/1111"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:impound_record)).to eq impound_record
    end
    context "id-" do
      it "renders" do
        impound_record.reload
        expect(impound_record.display_id).to eq 1111
        get "#{base_url}/pkey-#{impound_record.id}"
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(assigns(:impound_record)).to eq impound_record
      end
    end
    context "not found" do
      it "raises" do
        expect {
          get "#{base_url}/2812912"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "update" do
    let(:kind) { "note" }
    let(:update_params) { {notes: "OK boomer", kind: kind} }
    let!(:ownership_original) { FactoryBot.create(:ownership, bike: bike) }
    before do
      expect(impound_record).to be_present
      ImpoundUpdateBikeWorker.new.perform(impound_record.id)
      ActionMailer::Base.deliveries = []
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.inline!
    end
    after { Sidekiq::Testing.fake! }
    it "updates" do
      expect {
        patch "#{base_url}/#{impound_record.display_id}", params: {impound_record_update: update_params}
      }.to change(ImpoundRecordUpdate, :count).by 1
      expect(response).to redirect_to "#{base_url}/#{impound_record.display_id}"
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
        expect {
          patch "#{base_url}/#{impound_record.display_id}", params: {impound_record_update: update_params}
        }.to change(ImpoundRecordUpdate, :count).by 1
        expect(response).to redirect_to "#{base_url}/#{impound_record.display_id}"
        expect(ActionMailer::Base.deliveries.count).to eq 0
        impound_record.reload
        expect(impound_record.impound_record_updates.count).to eq 1
        expect(impound_record.active?).to be_falsey
        expect(impound_record.resolved_at).to be_within(15).of Time.current
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
      let(:kind) { "removed_from_bike_index" }
      it "deletes, updates user on the impound_record" do
        expect(impound_record.user).to_not eq current_user
        expect {
          patch "#{base_url}/#{impound_record.display_id}", params: {impound_record_update: update_params}
        }.to change(ImpoundRecordUpdate, :count).by 1
        expect(flash).to be_blank
        expect(response).to redirect_to "#{base_url}/#{impound_record.display_id}"
        expect(ActionMailer::Base.deliveries.count).to eq 0
        impound_record.reload
        expect(impound_record.impound_record_updates.count).to eq 1
        expect(impound_record.active?).to be_falsey
        expect(impound_record.resolved_at).to be_within(15).of Time.current
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
    context "transferred_to_new_owner" do
      let(:kind) { "transferred_to_new_owner" }
      let(:update_params_with_email) { update_params.merge(transfer_email: "a@b.c") }
      it "sends to a new owner" do
        bike.reload
        expect(bike.status_impounded?).to be_truthy
        expect {
          patch "#{base_url}/#{impound_record.display_id}", params: {impound_record_update: update_params_with_email}
        }.to change(ImpoundRecordUpdate, :count).by 1
        expect(flash).to be_blank
        expect(response).to redirect_to "#{base_url}/#{impound_record.display_id}"
        expect(ActionMailer::Base.deliveries.count).to eq 1
        impound_record.reload
        expect(impound_record.impound_record_updates.count).to eq 1
        expect(impound_record.active?).to be_falsey
        expect(impound_record.resolved_at).to be_within(15).of Time.current
        expect(impound_record.status).to eq "transferred_to_new_owner"
        impound_record_update = impound_record.impound_record_updates.last
        expect(impound_record.resolving_update).to eq impound_record_update
        expect(impound_record_update.kind).to eq "transferred_to_new_owner"
        expect(impound_record_update.notes).to eq "OK boomer"
        expect(impound_record_update.user).to eq current_user
        expect(impound_record_update.resolved).to be_truthy

        bike.reload
        expect(bike.owner_email).to eq "a@b.c"
        expect(bike.status_with_owner?).to be_truthy
        expect(bike.ownerships.count).to eq 2
        expect(bike.current_ownership.impound_record).to eq impound_record
        expect(bike.current_ownership.organization).to eq current_organization
        expect(bike.current_ownership.owner_email).to eq "a@b.c"
      end
      context "without a transfer_email" do
        it "returns with a flash error" do
          expect {
            put "#{base_url}/#{impound_record.display_id}", params: {impound_record_update: update_params}
          }.to_not change(ImpoundRecordUpdate, :count)
          expect(flash[:error]).to be_present
          expect(response).to render_template(:show)
          expect(ActionMailer::Base.deliveries.count).to eq 0
          impound_record.reload
          expect(impound_record.current?).to be_truthy
        end
      end
      context "unregistered_parking_notification" do
        let(:parking_notification) do
          pn = FactoryBot.create(:unregistered_parking_notification,
            created_at: Time.current - 1.hour,
            organization: current_organization,
            user: current_user,
            kind: "impound_notification")
          # Process parking_notification in the actual code path that creates the impound record
          ProcessParkingNotificationWorker.new.perform(pn.id)
          pn.reload
          pn
        end
        let(:bike) { parking_notification.bike }
        let!(:impound_record) { parking_notification.impound_record }
        let!(:ownership_original) { nil }
        it "sends to a new owner, ensures mark user hidden is off" do
          parking_notification.reload
          bike.reload
          impound_record.reload
          expect(parking_notification.impound_record_id).to eq impound_record.id
          expect(parking_notification.bike_id).to eq impound_record.bike_id
          expect(parking_notification.bike_id).to eq bike.id
          expect(parking_notification.unregistered_bike).to be_truthy
          expect(bike.created_by_parking_notification).to be_truthy
          expect(bike.status).to eq "status_impounded"
          expect(bike.current_impound_record).to eq impound_record
          expect(impound_record.current?).to be_truthy
          expect(bike.ownerships.count).to eq 1
          expect {
            put "#{base_url}/#{impound_record.display_id}", params: {impound_record_update: update_params_with_email}
          }.to change(ImpoundRecordUpdate, :count).by 1
          expect(flash).to be_blank
          expect(response).to redirect_to "#{base_url}/#{impound_record.display_id}"
          expect(ActionMailer::Base.deliveries.count).to eq 1
          impound_record.reload
          expect(impound_record.impound_record_updates.count).to eq 1
          expect(impound_record.active?).to be_falsey
          expect(impound_record.resolved_at).to be_within(15).of Time.current
          expect(impound_record.status).to eq "transferred_to_new_owner"
          impound_record_update = impound_record.impound_record_updates.last
          expect(impound_record.resolving_update).to eq impound_record_update
          expect(impound_record_update.kind).to eq "transferred_to_new_owner"
          expect(impound_record_update.notes).to eq "OK boomer"
          expect(impound_record_update.user).to eq current_user
          expect(impound_record_update.resolved).to be_truthy

          bike.reload
          expect(bike.owner_email).to eq "a@b.c"
          expect(bike.status_with_owner?).to be_truthy
          expect(bike.ownerships.count).to eq 2
          expect(bike.current_ownership.impound_record).to eq impound_record
          expect(bike.current_ownership.organization).to eq current_organization
          expect(bike.current_ownership.owner_email).to eq "a@b.c"
          expect(bike.current_ownership.calculated_send_email).to be_truthy
        end
      end
    end
    context "with locations" do
      let(:kind) { "move_location" }
      let!(:location) { FactoryBot.create(:location, organization: current_organization, impound_location: true, default_impound_location: true) }
      let!(:location2) do
        # Need to do this here, to ensure the current location is set in before block
        current_organization.reload
        expect(current_organization.default_impound_location).to eq location
        FactoryBot.create(:location, organization: current_organization, impound_location: true)
      end
      it "updates, moves to a new location" do
        expect(current_organization.enabled?("impound_bikes_locations")).to be_truthy
        impound_record.update(updated_at: Time.current)
        expect(impound_record.location).to eq location
        bike.reload
        expect(bike.status).to eq "status_impounded"
        expect {
          put "#{base_url}/#{impound_record.display_id}", params: {
            impound_record_update: {
              kind: kind,
              location_id: location2.id
            }
          }
        }.to change(ImpoundRecordUpdate, :count).by 1
        expect(response).to redirect_to "#{base_url}/#{impound_record.display_id}"
        expect(ActionMailer::Base.deliveries.count).to eq 0
        impound_record.reload
        expect(impound_record.impound_record_updates.count).to eq 1
        expect(impound_record.status).to eq "current"
        expect(impound_record.location).to eq location2
        impound_record_update = impound_record.impound_record_updates.last
        expect(impound_record_update.kind).to eq "move_location"
        expect(impound_record_update.location).to eq location2
        expect(impound_record_update.notes).to be_blank
        expect(impound_record_update.user).to eq current_user
        expect(impound_record_update.resolved).to be_truthy

        bike.reload
        expect(bike.status).to eq "status_impounded"
      end
    end
  end
end
