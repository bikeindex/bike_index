require "rails_helper"

RSpec.describe Callbacks::AfterManufacturerChangeJob, type: :job do
  let(:instance) { described_class.new }

  let(:manufacturer) { FactoryBot.create(:manufacturer, name: "something") }

  let!(:bike) { FactoryBot.create(:bike, manufacturer:) }
  let!(:bike1) { FactoryBot.create(:bike, manufacturer: Manufacturer.other, manufacturer_other: "PEDEGO") }
  let!(:bike2) { FactoryBot.create(:bike, manufacturer: Manufacturer.other, manufacturer_other: "PEDEGO ELECTRIC bikes ") }
  let!(:bike3) { FactoryBot.create(:bike, manufacturer: Manufacturer.other, manufacturer_other: "PEDEGOgo") }
  let!(:bike4) { FactoryBot.create(:bike, manufacturer: Manufacturer.other, manufacturer_other: "PEDEGOes") }
  let!(:component1) { FactoryBot.create(:component, bike:, manufacturer: Manufacturer.other, manufacturer_other: "\nPEDEGO ELECTRIC bikes ") }
  let!(:component2) { FactoryBot.create(:component, bike:, manufacturer: Manufacturer.other, manufacturer_other: "   PEDEGOes") }

  it "assigns the user coordinates" do
    expect(bike2.reload.manufacturer_other).to eq "PEDEGO ELECTRIC bikes"

    Sidekiq::Job.clear_all
    manufacturer.update(name: "Pedego Electric Bikes (Pedegogo)")
    expect(manufacturer.reload.priority).to eq 0
    expect(described_class.jobs.count).to eq 1

    expect do
      instance.perform(manufacturer.id)
    end.to_not change(described_class.jobs, :count)

    expect(bike.reload.manufacturer_id).to eq manufacturer.id

    expect(bike1.reload.manufacturer_id).to eq manufacturer.id
    expect(bike1.manufacturer_other).to be_nil

    expect(bike2.reload.manufacturer_id).to eq manufacturer.id
    expect(bike2.manufacturer_other).to be_nil

    expect(bike3.reload.manufacturer_id).to eq manufacturer.id
    expect(bike3.manufacturer_other).to be_nil

    expect(bike4.reload.manufacturer_id).to eq Manufacturer.other.id
    expect(bike4.manufacturer_other).to eq "PEDEGOes"

    expect(component1.reload.manufacturer_id).to eq manufacturer.id
    expect(component1.manufacturer_other).to be_nil

    expect(component2.reload.manufacturer_id).to eq Manufacturer.other.id
    expect(component2.manufacturer_other).to eq "PEDEGOes"

    expect(manufacturer.reload.priority).to eq 10
  end
end
