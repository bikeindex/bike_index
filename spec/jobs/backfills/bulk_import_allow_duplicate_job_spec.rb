require "rails_helper"

RSpec.describe Backfills::BulkImportAllowDuplicateJob, type: :job do
  describe "perform" do
    let!(:no_duplicate) { FactoryBot.create(:bulk_import, data: {"no_duplicate" => true, "matched_count" => 2}) }
    let!(:duplicate) { FactoryBot.create(:bulk_import, data: {"no_duplicate" => false}) }
    let!(:no_data) { FactoryBot.create(:bulk_import, data: nil) }
    let!(:stolen) { FactoryBot.create(:bulk_import, kind: "stolen", data: {"stolen_record" => {"phone" => "1112223333"}}) }
    let!(:already_set) { FactoryBot.create(:bulk_import, allow_duplicate: false) }

    it "sets allow_duplicate from the historical no_duplicate" do
      described_class.new.perform

      expect(no_duplicate.reload.data).to eq({"allow_duplicate" => false, "matched_count" => 2})
      expect(duplicate.reload.data).to eq({"allow_duplicate" => true})
      expect(no_data.reload.data).to eq({"allow_duplicate" => true})
      expect(stolen.reload.data).to eq({"stolen_record" => {"phone" => "1112223333"}, "allow_duplicate" => true})
      expect(already_set.reload.data).to eq({"allow_duplicate" => false})
    end
  end
end
