require "rails_helper"

RSpec.describe PropulsionType, type: :model do
  describe "find_sym" do
    it "finds" do
      expect(PropulsionType.find_sym("hand cycle")).to eq :"hand-pedal"
    end
  end
  describe "normalized name" do
    let(:slug) { :"pedal-assist" }

    it "returns the slug's normalized name" do
      pt = PropulsionType.new(slug)
      expect(pt.name).to eq("Pedal Assist")
    end
  end

  describe "friendly_find" do
    let(:name) { :"pedal-assist-and-throttle" }
    it "tries to find the slug, given a name" do
      finder = PropulsionType.friendly_find(name)
      expect(finder.slug).to eq name
    end
    context "slug" do
      let(:name) { "Human powered" }
      it "tries to find the slug, given a name" do
        finder = PropulsionType.friendly_find(name)
        expect(finder.slug).to eq :"human-not-pedal"
      end
    end
  end

  describe "for_vehicle" do
    it "is foot-pedal" do
      expect(PropulsionType.for_vehicle("bike")).to eq :"foot-pedal"
      expect(PropulsionType.for_vehicle("unicycle")).to eq :"foot-pedal"
      expect(PropulsionType.for_vehicle("unicycle")).to eq :"foot-pedal"
    end

    context "non-pedal" do
      (CycleType.slugs_sym - CycleType::PEDALS - CycleType::ALWAYS_MOTORIZED).each do |cycle_type|
        it "is human-not-pedal for '#{cycle_type}'" do
          expect(CycleType::PEDALS).to_not include(cycle_type)
          expect(PropulsionType.for_vehicle(cycle_type)).to eq :"human-not-pedal"
        end
      end
    end

    context "ALWAYS_MOTORIZED CycleType" do
      CycleType::ALWAYS_MOTORIZED.each do |cycle_type|
        it "is throttle for '#{cycle_type}'" do
          expect(PropulsionType.for_vehicle(cycle_type, :"hand-pedal")).to eq :throttle
        end
      end
    end

    context "NEVER_MOTORIZED CycleType" do
      (CycleType::NEVER_MOTORIZED - %i[trail-behind]).each do |cycle_type|
        it "is human-not-pedal for '#{cycle_type}'" do
          expect(PropulsionType.for_vehicle(cycle_type)).to eq :"human-not-pedal"
          expect(PropulsionType.for_vehicle(cycle_type, :motorized)).to eq :"human-not-pedal"
          expect(PropulsionType.for_vehicle(cycle_type, :throttle)).to eq :"human-not-pedal"
        end
      end
      it "is foot-pedal for 'trail-behind'" do
        cycle_type = :"trail-behind"
        expect(CycleType::NEVER_MOTORIZED).to include(cycle_type)
        expect(PropulsionType.for_vehicle(cycle_type)).to eq :"foot-pedal"
        expect(PropulsionType.for_vehicle(cycle_type, :motorized)).to eq :"foot-pedal"
        expect(PropulsionType.for_vehicle(cycle_type, :throttle)).to eq :"foot-pedal"
      end
    end

    context "passed motorized" do
      it "is default_motorized_type" do
        expect(PropulsionType.for_vehicle(:bike, :motorized)).to eq :"pedal-assist"
        expect(PropulsionType.for_vehicle(:wheelchair, :motorized)).to eq :"throttle"
        expect(PropulsionType.for_vehicle(:stroller, :motorized)).to eq :"throttle"
      end
    end
  end

  describe "default_motorized_type" do
    it "is pedal-assist for bike" do
      expect(PropulsionType.default_motorized_type(:bike)).to eq(:"pedal-assist")
    end
  end
end
