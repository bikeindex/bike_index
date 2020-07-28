require "rails_helper"

RSpec.describe ImpoundUpdateBikeWorker, type: :job do
  let(:instance) { described_class.new }

  let(:bike) { FactoryBot.create(:bike, updated_at: Time.current - 2.hours) }
  let!(:impound_record) { FactoryBot.create(:impound_record, bike: bike) }
  let(:impound_record_update) { FactoryBot.build(:impound_record_update, impound_record: impound_record, resolved: false, kind: kind) }
  let(:kind) { "note" }

  it "resolves the impound_record_update" do
    bike.reload
    expect(bike.status_impounded?).to be_falsey
    expect(bike.updated_at).to be < Time.current - 1.minute

    impound_record_update.save
    Sidekiq::Worker.clear_all
    described_class.new.perform(impound_record.id)
    expect(described_class.jobs.count).to eq 0

    impound_record_update.reload
    expect(impound_record_update.resolved).to be_truthy

    bike.reload
    expect(bike.status_impounded?).to be_truthy
    expect(bike.updated_at).to be_within(1).of Time.current
  end

  context "unregistered_parking_notification" do
    let(:bike) { FactoryBot.create(:bike, updated_at: Time.current - 2.hours, status: "unregistered_parking_notification") }
    let!(:parking_notification) { FactoryBot.create(:unregistered_parking_notification, kind: "impound_notification", bike: bike) }
    it "marks the bike not hidden" do
      impound_record.update(parking_notification: parking_notification)
      impound_record.reload
      bike.reload
      expect(bike.hidden).to be_truthy
      expect(bike.user_hidden).to be_truthy
      expect(parking_notification.unregistered_bike?).to be_truthy
      expect(impound_record.unregistered_bike?).to be_truthy
      instance.perform(impound_record.id)
      impound_record.reload
      bike.reload
      expect(bike.hidden).to be_falsey
      expect(bike.marked_user_hidden).to be_falsey
      expect(impound_record.unregistered_bike?).to be_truthy
    end
  end

  context "id collision" do
    let(:organization) { impound_record.organization }
    let(:og_id) { impound_record.display_id }
    let!(:impound_record2) { FactoryBot.create(:impound_record, organization: organization, display_id: og_id) }
    let!(:impound_record3) { FactoryBot.create(:impound_record, organization: organization, display_id: og_id + 1) }
    it "fixes the issue" do
      expect(impound_record.display_id).to eq impound_record2.display_id
      expect(impound_record2.id).to be > impound_record.id
      Sidekiq::Worker.clear_all
      described_class.new.perform(impound_record.id)
      expect(described_class.jobs.count).to eq 0
      impound_record.reload
      impound_record2.reload
      impound_record3.reload
      expect(impound_record.display_id).to eq og_id
      expect(impound_record2.display_id).to eq og_id + 2
      expect(impound_record3.display_id).to eq og_id + 1
    end
  end

  context "retrieved by owner" do
    let(:kind) { "retrieved_by_owner" }
    it "marks the impound_record resolved" do
      bike.update(updated_at: Time.current)
      expect(bike.status_impounded?).to be_truthy

      impound_record_update.save
      Sidekiq::Worker.clear_all
      described_class.new.perform(impound_record.id)
      expect(described_class.jobs.count).to eq 0

      impound_record_update.reload
      expect(impound_record_update.resolved).to be_truthy

      impound_record.reload
      expect(impound_record.resolved_at).to be_within(1).of impound_record_update.created_at
      expect(impound_record.status).to eq kind

      bike.reload
      expect(bike.status_impounded?).to be_falsey
      expect(bike.updated_at).to be_within(1).of Time.current
    end
  end

  context "removed_from_index" do
    let(:kind) { "removed_from_bike_index" }
    it "deletes the bike" do
      impound_record_update.save
      Sidekiq::Worker.clear_all
      described_class.new.perform(impound_record.id)
      expect(described_class.jobs.count).to eq 0

      impound_record_update.reload
      expect(impound_record_update.resolved).to be_truthy

      impound_record.reload
      expect(impound_record.resolved_at).to be_within(1).of impound_record_update.created_at
      expect(impound_record.status).to eq kind
      expect(impound_record.bike).to be_present # Because we still want to show information about the bike

      expect(Bike.unscoped.find(bike.id).deleted?).to be_truthy
    end
  end

  context "transferred_to_new_owner" do
    let(:kind) { "transferred_to_new_owner" }
    let!(:ownership) { FactoryBot.create(:ownership, bike: bike, claimed: false) }
    it "creates 2 new ownerships, transfers it to the user, then to the new email, only sends one email" do
      impound_record_update.update(transfer_email: "something@party.com")
      expect(bike.ownerships.count).to eq 1
      Sidekiq::Worker.clear_all
      ActionMailer::Base.deliveries = []
      expect do
        Sidekiq::Testing.inline! do
          impound_record_update.save
          described_class.new.perform(impound_record.id)
        end
      end.to change(Ownership, :count).by 1
      expect(ActionMailer::Base.deliveries.count).to eq 1
      ownership.reload
      expect(ownership.current?).to be_falsey

      bike.reload
      new_ownership = bike.current_ownership
      expect(new_ownership.impound_record).to eq impound_record
      expect(new_ownership.organization).to eq impound_record.organization
      expect(new_ownership.current).to be_truthy
      expect(new_ownership.creator).to eq impound_record_update.user

      impound_record_update.reload
      expect(impound_record_update.resolved).to be_truthy

      impound_record.reload
      expect(impound_record.resolved_at).to be_within(1).of impound_record_update.created_at
      expect(impound_record.status).to eq kind
      expect(impound_record.bike.owner_email).to eq "something@party.com"
    end
  end
end
