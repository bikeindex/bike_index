require "rails_helper"

RSpec.describe MigrateCreationStateToOwnershipWorker, type: :job do
  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "migrate?" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:ownership) { FactoryBot.create(:ownership, bike: bike) }
    let!(:creation_state) { FactoryBot.create(:creation_state, bike: bike, creator: ownership.creator) }
    it "is falsey" do
      creation_state.reload
      ownership.reload
      expect(ownership.updated_at.to_i).to be > MigrateCreationStateToOwnershipWorker::END_TIMESTAMP
      expect(MigrateCreationStateToOwnershipWorker.migrate?(ownership, creation_state)).to be_falsey
    end
    context "before time" do
      let(:updated_at) { Time.at(1640030537) }
      it "is truthy" do
        creation_state.update_column :updated_at, updated_at
        ownership.update_column :updated_at, updated_at
        creation_state.reload
        ownership.reload
        expect(MigrateCreationStateToOwnershipWorker.migrate?(ownership, creation_state)).to be_truthy
      end
    end
  end
end
