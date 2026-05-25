require "rails_helper"

RSpec.describe Backfills::CountryNetherlandsAntillesToCuracaoJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    context "with no Netherlands Antilles country" do
      it "is a no-op" do
        expect { instance.perform }.not_to change(Country, :count)
      end
    end

    context "with Netherlands Antilles country and referencing rows" do
      let!(:antilles) { Country.create!(name: "Netherlands Antilles", iso: "AN") }
      let!(:stolen_record) { FactoryBot.create(:stolen_record, country_id: antilles.id) }
      let!(:address_record) { FactoryBot.create(:address_record, country_id: antilles.id) }

      it "re-points rows to Curaçao and destroys the AN country" do
        instance.perform

        curacao = Country.find_by(iso: "CW")
        expect(curacao).to be_present
        expect(curacao.name).to eq("Curaçao")
        expect(stolen_record.reload.country_id).to eq(curacao.id)
        expect(address_record.reload.country_id).to eq(curacao.id)
        expect(Country.find_by(iso: "AN")).to be_nil
      end

      context "with an existing Curaçao country" do
        let!(:curacao) { Country.create!(name: "Curaçao", iso: "CW") }

        it "reuses the existing Curaçao row" do
          expect { instance.perform }.to change(Country, :count).by(-1)
          expect(stolen_record.reload.country_id).to eq(curacao.id)
          expect(address_record.reload.country_id).to eq(curacao.id)
        end
      end
    end
  end
end
