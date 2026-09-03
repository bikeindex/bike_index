require "rails_helper"

RSpec.describe Backfills::CountriesSyncJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    context "with no Netherlands Antilles country" do
      it "is a no-op" do
        expect { instance.perform }.not_to change(Country, :count)
      end
    end

    context "with a country whose name has drifted from StatesAndCountries" do
      let!(:stale_macedonia) { Country.create!(name: "Macedonia, The Former Yugoslav Republic of", iso: "MK") }
      let!(:stale_swaziland) { Country.create!(name: "Swaziland", iso: "SZ") }
      let!(:already_synced) { Country.create!(name: "Germany", iso: "DE") }

      it "updates names to match StatesAndCountries (by iso) and leaves synced rows alone" do
        expect { instance.perform }
          .to change { stale_macedonia.reload.name }.to("North Macedonia")
          .and change { stale_swaziland.reload.name }.to("Eswatini")
        expect(already_synced.reload.name).to eq("Germany")
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
