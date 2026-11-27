# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikebookModelsDataSyncJob, type: :job do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  let(:instance) { described_class.new }
  let(:block_url) { %r{\A#{Regexp.escape(Integrations::Bikebook::Catalog::URL)}models/}o }
  def expect_block_reads(times) = WebMock::API.assert_requested(:get, block_url, times:)

  before do
    sync_bikebook_models
    BikebookModel.update_all(data: nil, data_file: nil)
    WebMock.reset_executed_requests!
  end

  it "syncs each synced model's records from its block, reading only the blocks a publish changed" do
    instance.perform
    expect(BikebookModel.where(data: nil).count).to eq 0
    expect(BikebookModel.find_by!(catalog_id: "m/specialized/2025/haul-st")).to have_attributes(data_file: "models/specialized/2025.json")
    expect(BikebookModel.find_by!(catalog_id: "m/specialized/2025/haul-st").data.keys)
      .to match_array(["m/specialized/2025/haul-st", "m/specialized/2025/haul-st@CA"])
    expect_block_reads(BikebookModel.distinct.count(:data_file))

    WebMock.reset_executed_requests!
    instance.perform
    expect_block_reads(0)

    stub_bikebook_catalog_update
    Rails.cache.clear
    Integrations::Bikebook::Catalog::Reads.reset
    instance.perform
    expect_block_reads(1)
    expect(BikebookModel.find_by!(catalog_id: "m/segway/2025/gt3-pro")).to have_attributes(data_file: "models/segway/2025.v2.json")
    expect(BikebookModel.find_by!(catalog_id: "m/segway/2025/gt3-pro").market_data["description"]).to eq "Updated"
  end

  context "with a model added to a block already synced" do
    it "reads the block again" do
      instance.perform
      haul_st = BikebookModel.find_by!(catalog_id: "m/specialized/2025/haul-st")
      haul_st.update!(data: nil, data_file: nil)

      WebMock.reset_executed_requests!
      instance.perform
      expect_block_reads(1)
      expect(haul_st.reload.data_file).to eq "models/specialized/2025.json"
    end
  end

  context "with the catalog unreachable" do
    it "keeps the data it has, reading no block past the first that fails" do
      instance.perform
      BikebookModel.update_all(data_file: nil)
      WebMock.stub_request(:get, block_url).to_return(status: 500)

      WebMock.reset_executed_requests!
      instance.perform
      expect_block_reads(1)
      expect(BikebookModel.where(data: nil).count).to eq 0
    end
  end
end
