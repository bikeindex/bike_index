require "rails_helper"

RSpec.describe ProcessImpoundUpdatesJob, type: :job do
  let(:instance) { described_class.new }

  let(:bike) { FactoryBot.create(:bike, :with_ownership, updated_at: Time.current - 2.hours) }
  let(:impound_record) { FactoryBot.create(:impound_record_with_organization, bike: bike) }
  let(:impound_record_update) { FactoryBot.build(:impound_record_update, impound_record: impound_record, processed: false, kind: kind) }
  let(:kind) { "note" }

  it "resolves the impound_record_update" do
    impound_record.reload
    # The factory force updates bike, so force un-update
    bike.update_columns(status: "status_with_owner", current_impound_record_id: nil)
    expect(bike.reload.status).to eq "status_with_owner"
    expect(bike.current_ownership.status).to eq "status_with_owner"

    impound_record_update.save
    Sidekiq::Job.clear_all
    described_class.new.perform(impound_record.id)
    expect(described_class.jobs.count).to eq 0

    impound_record_update.reload
    expect(impound_record_update.processed?).to be_truthy

    expect(bike.reload.status).to eq "status_impounded"
    expect(bike.updated_at).to be_within(1).of Time.current
    expect(bike.current_ownership.reload.status).to eq "status_with_owner"
  end

  context "unregistered_parking_notification" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership, updated_at: Time.current - 2.hours, status: "unregistered_parking_notification") }
    let!(:parking_notification) { FactoryBot.create(:parking_notification_unregistered, kind: "impound_notification", bike: bike) }
    it "marks the bike not hidden" do
      impound_record.update(parking_notification: parking_notification)
      impound_record.reload
      bike.reload
      expect(bike.user_hidden).to be_truthy
      expect(parking_notification.unregistered_bike?).to be_truthy
      expect(impound_record.unregistered_bike?).to be_truthy
      instance.perform(impound_record.id)
      impound_record.reload
      bike.reload
      expect(bike.user_hidden).to be_falsey
      expect(impound_record.unregistered_bike?).to be_truthy
    end
  end

  context "id collision" do
    let(:organization) { impound_record.organization }
    let(:og_id_integer) { impound_record.display_id_integer }
    let!(:impound_record2) { FactoryBot.create(:impound_record, organization: organization, display_id_integer: og_id_integer) }
    let!(:impound_record3) { FactoryBot.create(:impound_record, organization: organization, display_id_integer: og_id_integer + 1) }
    it "fixes the issue" do
      expect(impound_record.display_id).to eq impound_record2.display_id
      expect(impound_record2.id).to be > impound_record.id
      Sidekiq::Job.clear_all
      described_class.new.perform(impound_record.id)
      expect(described_class.jobs.count).to eq 0
      impound_record.reload
      impound_record2.reload
      impound_record3.reload
      expect(impound_record.display_id).to eq og_id_integer.to_s
      expect(impound_record2.display_id).to eq (og_id_integer + 2).to_s
      expect(impound_record3.display_id).to eq (og_id_integer + 1).to_s
    end
    context "there is a live prefix" do
      it "doesn't change the existing records prefixes" do
        expect(impound_record.display_id).to eq impound_record2.display_id
        expect(impound_record2.id).to be > impound_record.id
        organization.fetch_impound_configuration.update(display_id_prefix: "F", display_id_next_integer: 1111)
        Sidekiq::Job.clear_all
        described_class.new.perform(impound_record.id)
        expect(described_class.jobs.count).to eq 0
        impound_record.reload
        impound_record2.reload
        impound_record3.reload
        expect(impound_record.display_id).to eq og_id_integer.to_s
        expect(impound_record2.display_id).to eq (og_id_integer + 2).to_s
        expect(impound_record3.display_id).to eq (og_id_integer + 1).to_s
      end
    end
  end

  context "organization deleted" do
    let(:organization) { impound_record.organization }
    it "doesn't error" do
      expect(impound_record.organized?).to be_truthy
      organization.destroy
      impound_record.reload
      expect(impound_record.organization_id).to be_present
      expect(impound_record.organization).to be_nil
      described_class.new.perform(impound_record.id)
    end
  end

  context "display_id_next_integer" do
    let(:impound_configuration) { FactoryBot.create(:impound_configuration, display_id_prefix: "A", display_id_next_integer: 1212) }
    let(:organization) { impound_configuration.organization }
    let!(:impound_record) { FactoryBot.create(:impound_record, organization: organization, display_id_integer: 1212, display_id_prefix: "B") }
    let!(:impound_record2) { FactoryBot.create(:impound_record, organization: organization, display_id_integer: 1212, display_id_prefix: "A") }
    it "doesn't break things" do
      expect(organization.reload.fetch_impound_configuration.display_id_next_integer).to eq 1212
      expect(organization.fetch_impound_configuration.calculated_display_id_next).to eq "A1212"
      described_class.new.perform(impound_record.id)
      expect(impound_record.reload.display_id).to eq "B1212"
      expect(organization.reload.fetch_impound_configuration.display_id_next_integer).to eq 1212
      expect(organization.fetch_impound_configuration.calculated_display_id_next).to eq "A1212"

      described_class.new.perform(impound_record2.id)
      expect(impound_record2.reload.display_id).to eq "A1212"
      expect(organization.reload.fetch_impound_configuration.display_id_next_integer).to eq nil
      expect(organization.fetch_impound_configuration.calculated_display_id_next).to eq "A1213"
    end
  end

  context "retrieved by owner" do
    let(:kind) { "retrieved_by_owner" }
    it "marks the impound_record resolved" do
      impound_record.reload
      expect(bike.reload.status).to eq "status_impounded"

      impound_record_update.save
      Sidekiq::Job.clear_all
      described_class.new.perform(impound_record.id)
      expect(described_class.jobs.count).to eq 0

      impound_record_update.reload
      expect(impound_record_update.processed?).to be_truthy

      impound_record.reload
      expect(impound_record.resolved_at).to be_within(1).of impound_record_update.created_at
      expect(impound_record.status).to eq kind

      bike.reload
      expect(bike.reload.status).to eq "status_with_owner"
      expect(bike.updated_at).to be_within(1).of Time.current
    end
  end

  context "removed_from_index" do
    let(:kind) { "removed_from_bike_index" }
    it "deletes the bike" do
      impound_record_update.save
      Sidekiq::Job.clear_all
      described_class.new.perform(impound_record.id)
      expect(described_class.jobs.count).to eq 0

      impound_record_update.reload
      expect(impound_record_update.processed?).to be_truthy

      impound_record.reload
      expect(impound_record.resolved_at).to be_within(1).of impound_record_update.created_at
      expect(impound_record.status).to eq kind
      expect(impound_record.bike).to be_present # Because we still want to show information about the bike

      expect(Bike.unscoped.find(bike.id).deleted?).to be_truthy
    end
  end

  context "transferred_to_new_owner" do
    let(:kind) { "transferred_to_new_owner" }
    let!(:ownership) { bike.reload.current_ownership }
    let!(:impound_record_update) do
      impound_record.impound_record_updates.create(processed: false,
        kind: kind,
        transfer_email: "something@party.com",
        user: impound_record.user)
    end
    it "creates 2 new ownerships, transfers it to the user, then to the new email, only sends one email" do
      expect(bike.reload.ownerships.count).to eq 1
      expect(impound_record_update).to be_valid
      Sidekiq::Job.clear_all
      ActionMailer::Base.deliveries = []
      expect {
        Sidekiq::Testing.inline! do
          impound_record_update.save
          described_class.new.perform(impound_record.id)
        end
      }.to change(Ownership, :count).by 1
      expect(ActionMailer::Base.deliveries.count).to eq 1
      ownership.reload
      expect(ownership.current?).to be_falsey

      bike.reload
      expect(bike.status).to eq "status_with_owner"
      expect(bike.current_impound_record_id).to be_blank
      expect(bike.owner_email).to eq "something@party.com"

      new_ownership = bike.current_ownership
      expect(new_ownership.impound_record_id).to eq impound_record.id
      expect(new_ownership.organization).to eq impound_record.organization
      expect(new_ownership.current).to be_truthy
      expect(new_ownership.creator).to eq impound_record_update.user

      impound_record_update.reload
      expect(impound_record_update.processed?).to be_truthy

      impound_record.reload
      expect(impound_record.resolved_at).to be_within(1).of impound_record_update.created_at
      expect(impound_record.status).to eq kind
    end
  end
end
