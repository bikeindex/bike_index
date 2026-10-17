require "rails_helper"

RSpec.describe Backfills::RenamedAddressColumnsJob, type: :job do
  describe "perform" do
    let(:state) { FactoryBot.create(:state_new_york) }
    # Rows written before the models wrote the new columns
    def legacy(record, zipcode:, state_id:)
      record.update_columns(zipcode:, state_id:, postal_code: nil, region_record_id: nil)
      record
    end

    before { stub_const("#{described_class}::BATCH_SIZE", 2) }

    # account_info skips the twitter fetch on save
    {logged_search: {}, social_account: {account_info: {name: "name"}}}.each do |factory, attrs|
      context factory.to_s do
        let!(:records) { Array.new(3) { legacy(FactoryBot.create(factory, attrs), zipcode: "10007", state_id: state.id) } }
        let!(:blank) { legacy(FactoryBot.create(factory, attrs), zipcode: nil, state_id: nil) }
        let!(:current) { FactoryBot.create(factory, attrs.merge(zipcode: "60608")) }

        it "copies zipcode and state_id" do
          expect(current.reload.postal_code).to eq "60608"
          updated_at = records.first.reload.updated_at

          Sidekiq::Testing.inline! { described_class.perform_async(factory.to_s.camelize) }

          records.each do |record|
            expect(record.reload).to have_attributes(postal_code: "10007", region_record_id: state.id)
          end
          expect(records.first.updated_at).to eq updated_at
          expect(blank.reload).to have_attributes(postal_code: nil, region_record_id: nil)
          expect(current.reload).to have_attributes(postal_code: "60608", region_record_id: nil)
        end
      end
    end
  end
end
