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
      expect(finder.motorized?).to be_truthy
      expect(finder.human_powered?).to be_falsey
    end
    context "slug" do
      let(:name) { "Human powered" }
      it "tries to find the slug, given a name" do
        finder = PropulsionType.friendly_find(name)
        expect(finder.slug).to eq :"human-not-pedal"
        expect(finder.motorized?).to be_falsey
        expect(finder.human_powered?).to be_truthy
      end
    end
  end

  describe "for_vehicle" do
    it "is foot-pedal" do
      expect(PropulsionType.for_vehicle("bike")).to eq :"foot-pedal"
      expect(PropulsionType.for_vehicle("unicycle")).to eq :"foot-pedal"
      expect(PropulsionType.for_vehicle("unicycle")).to eq :"foot-pedal"
    end

    context "pedal_type cycle_type" do
      it "is what it is passed" do
        expect(PropulsionType.for_vehicle(:cargo, :"hand-pedal")).to eq :"hand-pedal"
        expect(PropulsionType.for_vehicle(:"trail-behind", :"hand-pedal")).to eq :"hand-pedal"
        expect(PropulsionType.for_vehicle(:unicycle, :throttle)).to eq :throttle
        expect(PropulsionType.for_vehicle(:bike, :throttle)).to eq :throttle
      end
      it "is default pedal_type if passed non pedal type" do
        expect(PropulsionType.for_vehicle(:bike, :"human-not-pedal")).to eq :"foot-pedal"
        expect(PropulsionType.for_vehicle(:unicycle, :"human-not-pedal")).to eq :"foot-pedal"
      end
    end

    context "not pedal_type cycle_type" do
      it "is human-not-pedal if pedal_type" do
        expect(PropulsionType.for_vehicle(:wheelchair, :"hand-pedal")).to eq :"human-not-pedal"
        expect(PropulsionType.for_vehicle(:wheelchair, :"foot-pedal")).to eq :"human-not-pedal"
        expect(PropulsionType.for_vehicle(:"non-e-scooter", :"foot-pedal")).to eq :"human-not-pedal"
        expect(PropulsionType.for_vehicle(:"non-e-scooter", :"hand-pedal")).to eq :"human-not-pedal"

        expect(PropulsionType.for_vehicle(:wheelchair, :motorized)).to eq :"throttle"
        # Not sure - this might make more sense to make motorized? whatever
        expect(PropulsionType.for_vehicle(:wheelchair, :"pedal-assist")).to eq :"throttle"
        expect(PropulsionType.for_vehicle(:wheelchair, :"pedal-assist-and-throttle")).to eq :"throttle"
      end
    end

    context "non-pedal" do
      (CycleType.slugs_sym - CycleType::PEDAL - CycleType::ALWAYS_MOTORIZED).each do |cycle_type|
        it "is human-not-pedal for '#{cycle_type}'" do
          expect(CycleType::PEDAL).to_not include(cycle_type)
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
