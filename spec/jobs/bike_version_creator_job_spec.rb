require "rails_helper"

RSpec.describe BikeVersionCreatorJob, type: :job do
  let(:instance) { described_class.new }

  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, manufacturer: Manufacturer.other, manufacturer_other: "Unknown cool MNFG") }
  let(:user) { bike.user }
  it "creates the bike_version" do
    expect(bike.reload.bike_versions.count).to eq 0
    expect {
      instance.perform(bike.id)
    }.to change(BikeVersion, :count).by 1
    expect(bike.reload.bike_versions.count).to eq 1
    bike_version = bike.bike_versions.first
    expect(bike_version.owner_id).to eq user.id
    expect(bike_version.authorized?(user)).to be_truthy
    expect(bike_version.manufacturer_id).to eq Manufacturer.other.id
    expect(bike_version.mnfg_name).to eq "Unknown cool MNFG"
    expect(bike_version.frame_colors).to eq bike.frame_colors
  end
  context "with all the associations" do
    let(:color1) { FactoryBot.create(:color) }
    let(:black) { Color.black }
    let(:color2) { FactoryBot.create(:color) }
    let(:wheel_size1) { FactoryBot.create(:wheel_size) }
    let(:wheel_size2) { FactoryBot.create(:wheel_size) }
    let(:front_gear_type) { FactoryBot.create(:front_gear_type) }
    let(:rear_gear_type) { FactoryBot.create(:rear_gear_type) }
    let(:paint) { FactoryBot.create(:paint) }
    let(:bike) do
      FactoryBot.create(:bike, :with_ownership_claimed,
        cycle_type: "cargo",
        handlebar_type: "rearward",
        propulsion_type: "pedal-assist",
        frame_material: "organic",
        year: 1969,
        name: "My cool bike",
        frame_model: "Cool model name",
        description: "A really cool description",
        number_of_seats: 3,
        primary_frame_color: color1,
        secondary_frame_color: black,
        tertiary_frame_color: color2,
        front_wheel_size: wheel_size1,
        front_tire_narrow: false,
        rear_wheel_size: wheel_size2,
        rear_tire_narrow: true,
        front_gear_type: front_gear_type,
        rear_gear_type: rear_gear_type,
        paint: paint,
        belt_drive: true,
        coaster_brake: true,
        frame_size: "xl",
        frame_size_unit: "ordinal")
    end
    let(:component_manufacturer) { FactoryBot.create(:manufacturer, frame_maker: false) }
    let!(:component1) { FactoryBot.create(:component, bike: bike, manufacturer: component_manufacturer, description: "some description", front: true, year: 2020) }
    let(:component_attrs) do
      {
        bike_id: bike.id,
        manufacturer: Manufacturer.other,
        manufacturer_other: "Some other Manufacturer",
        component_model: "party",
        serial_number: "999999FFF",
        year: "2020"
      }
    end
    let(:target_cached_array) do
      [
        bike.mnfg_name,
        bike.frame_size,
        bike.type,
        bike.propulsion_type_name,
        bike.year,
        bike.frame_material_name,
        bike.frame_model,
        bike.primary_frame_color.name,
        bike.secondary_frame_color.name,
        bike.tertiary_frame_color.name,
        "#{bike.rear_wheel_size.name} wheel",
        "#{bike.front_wheel_size.name} wheel",
        component_manufacturer.short_name,
        "Some other Manufacturer",
        "party",
        2020
      ]
    end
    let!(:component2) { FactoryBot.create(:component, component_attrs) }
    it "creates" do
      expect(bike.reload.bike_versions.count).to eq 0
      expect(user).to be_present
      expect(component2.reload.mnfg_name).to eq "Some other Manufacturer"
      expect {
        instance.perform(bike.id)
      }.to change(BikeVersion, :count).by 1
      expect(bike.reload.bike_versions.count).to eq 1
      bike_version = bike.bike_versions.first
      expect(bike_version.owner_id).to eq user.id
      expect(bike_version.authorized?(user)).to be_truthy
      expect(bike_version.mnfg_name).to eq bike.manufacturer.name
      expect(bike_version.frame_colors).to eq([color1.name, "Black", color2.name])
      expect(bike_version.cycle_type_name).to eq "Cargo Bike (front storage)"
      expect(bike_version.handlebar_type_name).to eq "Rear facing"
      expect(bike_version.propulsion_type_name).to eq "Pedal Assist"
      expect(bike_version.frame_material_name).to eq "Wood or organic material"
      expect(bike_version.name).to eq "My cool bike, Version 1"
      expect(bike_version.year).to eq 1969
      expect(bike_version.frame_model).to eq "Cool model name"
      expect(bike_version.description).to eq "A really cool description"
      expect(bike_version.number_of_seats).to eq 3
      expect(bike_version.primary_frame_color_id).to eq color1.id
      expect(bike_version.secondary_frame_color_id).to eq black.id
      expect(bike_version.tertiary_frame_color_id).to eq color2.id
      expect(bike_version.front_wheel_size_id).to eq wheel_size1.id
      expect(bike_version.front_tire_narrow).to eq false
      expect(bike_version.rear_wheel_size_id).to eq wheel_size2.id
      expect(bike_version.rear_tire_narrow).to eq true
      expect(bike_version.front_gear_type_id).to eq front_gear_type.id
      expect(bike_version.rear_gear_type_id).to eq rear_gear_type.id
      expect(bike_version.paint_id).to eq paint.id
      expect(bike_version.frame_size).to eq "xl"
      expect(bike_version.frame_size_unit).to eq "ordinal"
      expect(bike_version.frame_size_number).to eq nil
      expect(bike_version.status).to eq "status_with_owner"
      # And the final test - does everything calculate?
      expect(bike_version.cached_data_array).to match_array target_cached_array
      # And, test that bike is the same
      expect(bike.cached_data).to eq bike_version.cached_data

      expect(bike_version.components.count).to eq 2
      version_component1 = bike_version.components.where(manufacturer_id: component_manufacturer.id).first
      expect(version_component1.description).to eq "some description"
      expect(version_component1.front).to be_truthy

      version_component2 = bike_version.components.where.not(id: version_component1.id).first
      expect(version_component2).to match_hash_indifferently component_attrs.except(:bike_id)
    end
  end
  context "with public_images" do
    let(:large_image) { File.open(Rails.root.join("spec/fixtures/hugeimg.png")) }
    let!(:public_image) { FactoryBot.create(:public_image, image: large_image, imageable: bike) }
    it "copies them" do
      bike.reload
      expect(bike.public_images.count).to eq 1
      expect {
        instance.perform(bike.id)
      }.to change(BikeVersion, :count).by 1
      expect(bike.reload.bike_versions.count).to eq 1
      bike_version = bike.bike_versions.first
      expect(bike_version.owner_id).to eq user.id
      expect(bike_version.authorized?(user)).to be_truthy
      expect(bike_version.manufacturer_id).to eq Manufacturer.other.id
      expect(bike_version.mnfg_name).to eq "Unknown cool MNFG"
      expect(bike_version.frame_colors).to eq bike.frame_colors
      expect(bike_version.public_images.count).to eq 1
    end
  end
end
