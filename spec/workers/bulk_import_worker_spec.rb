require 'spec_helper'

describe BulkImportWorker do
  let(:subject) { BulkImportWorker }
  let(:instance) { subject.new }
  it { is_expected.to be_processed_in :afterward }
  let(:organization) { FactoryGirl.create(:organization) }

  describe 'load_file' do
    it 'loads and parses a csv from an external source' do
    end
    context "file doesn't exist" do
      it 'creates an bulk import record with an error'
    end
    context 'invalid file' do
      it 'creates an bulk import record with an error'
    end
    context 'without a header' do
      it 'creates an bulk import record with an error'
    end
  end

  describe 'perform' do
    it 'registers multiple bikes' do
    end
    context 'bulk import already exists' do
      let!(:bulk_import) { FactoryGirl.create(:bulk_import, organization: organization) }
      it 'returns the existing bulk import' do
        expect(instance.perform(bulk_import.file_url, organization.id)).to eq bulk_import
      end
    end
  end
end
