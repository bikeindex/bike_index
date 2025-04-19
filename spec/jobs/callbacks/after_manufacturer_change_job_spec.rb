require "rails_helper"

RSpec.describe Callbacks::AfterManufacturerChangeJob, type: :job do
  let(:instance) { described_class.new }

  let(:manufacturer) { FactoryBot.create(:manufacturer, name: "something") }

  let!(:bike) { FactoryBot.create(:bike, manufacturer:) }
  let!(:bike1) { FactoryBot.create(:bike, manufacturer: Manufacturer.other, manufacturer_other: "PEDEGO") }
  let!(:bike2) { FactoryBot.create(:bike, manufacturer: Manufacturer.other, manufacturer_other: "PEDEGO ELECTRIC bikes ") }
  let!(:bike3) { FactoryBot.create(:bike, manufacturer: Manufacturer.other, manufacturer_other: "PEDEGOes") }

  it "assigns the user coordinates" do
    expect(bike2.reload.manufacturer_other).to eq "PEDEGO ELECTRIC bikes"

    manufacturer.update(name: "Pedego (Pedego Electric Bikes)")
    expect(manufacturer.priority).to eq 0
    instance.perform(manufacturer.id)

    expect(bike.reload.manufacturer_id).to eq manufacturer.id

    expect(bike1.reload.manufacturer_id).to eq manufacturer.id
    expect(bike1.manufacturer_other).to be_nil

    expect(bike2.reload.manufacturer_id).to eq manufacturer.id
    expect(bike2.manufacturer_other).to be_nil

    expect(bike3.reload.manufacturer_id).to eq Manufacturer.other.id
    expect(manufacturer.reload.priority).to eq 10
  end
end
