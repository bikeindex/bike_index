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

    it "is hand-pedal" do
      expect(PropulsionType.for_vehicle("bike", "hand-pedal")).to eq :"hand-pedal"
      expect(PropulsionType.find_sym("Hand Cycle")).to eq :"hand-pedal"
      expect(PropulsionType.for_vehicle("bike", "Hand Cycle")).to eq :"hand-pedal"
      expect(PropulsionType.for_vehicle("bike", "Hand Cycle (hand pedal)")).to eq :"hand-pedal"
      expect(PropulsionType.find_sym("Hand CYCLE (hand pedal) ")).to eq :"hand-pedal"
      expect(PropulsionType.for_vehicle("bike", "Hand CYCLE (hand pedal) ")).to eq :"hand-pedal"
    end

    context "pedal_type cycle_type" do
      it "is what it is passed" do
        expect(PropulsionType.for_vehicle(:cargo, :"hand-pedal")).to eq :"hand-pedal"
        expect(PropulsionType.for_vehicle(:"trail-behind", :"hand-pedal")).to eq :"hand-pedal"
        expect(PropulsionType.for_vehicle(:unicycle, :throttle)).to eq :throttle
        expect(PropulsionType.for_vehicle(:bike, :throttle)).to eq :throttle
      end
      it "is passed value if pedal type" do
        expect(PropulsionType.for_vehicle(:bike, :"human-not-pedal")).to eq :"human-not-pedal"
        expect(PropulsionType.for_vehicle(:unicycle, :"human-not-pedal")).to eq :"human-not-pedal"
      end
    end

    context "not pedal_type cycle_type" do
      it "is passed value if valid" do
        expect(PropulsionType.for_vehicle(:wheelchair, :"human-not-pedal")).to eq :"human-not-pedal"
        expect(PropulsionType.for_vehicle(:"e-scooter", :throttle)).to eq :throttle
      end

      it "is human-not-pedal" do
        expect(PropulsionType.for_vehicle(:wheelchair, :"foot-pedal")).to eq :"human-not-pedal"
        expect(PropulsionType.for_vehicle(:"non-e-skateboard", :"hand-pedal")).to eq :"human-not-pedal"
        expect(PropulsionType.for_vehicle(:"non-e-scooter", :"foot-pedal")).to eq :"human-not-pedal"
        expect(PropulsionType.for_vehicle(:"non-e-scooter", :"hand-pedal")).to eq :"human-not-pedal"
        (CycleType.slugs_sym - CycleType::PEDAL - CycleType::ALWAYS_MOTORIZED).each do |cycle_type|
          expect(PropulsionType.for_vehicle(cycle_type)).to eq :"human-not-pedal"
        end
      end

      it "is throttle if motorized" do
        expect(PropulsionType.for_vehicle(:stroller, :"pedal-assist")).to eq :throttle
        expect(PropulsionType.for_vehicle(:"personal-mobility", :"pedal-assist")).to eq :throttle
        expect(PropulsionType.for_vehicle(:"e-scooter", :"pedal-assist-and-throttle")).to eq :throttle
        expect(PropulsionType.for_vehicle(:"e-motorcycle", :"hand-pedal")).to eq :throttle
        (CycleType.slugs_sym - CycleType::PEDAL - CycleType::NEVER_MOTORIZED).each do |cycle_type|
          expect(PropulsionType.for_vehicle(cycle_type, :motorized)).to eq :throttle
        end
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
        expect(PropulsionType.for_vehicle(:wheelchair, :motorized)).to eq :throttle
        expect(PropulsionType.for_vehicle(:stroller, :motorized)).to eq :throttle
      end
    end
  end

  describe "valid_propulsion_types_for" do
    it "is all the types for bike" do
      expect(PropulsionType.valid_propulsion_types_for(:bike)).to eq(PropulsionType.slugs_sym)
      expect(PropulsionType.valid_propulsion_types_for(:tricycle)).to eq(PropulsionType.slugs_sym)
    end
    context "wheelchair" do
      it "is valid types" do
        expect(PropulsionType.valid_propulsion_types_for(:wheelchair)).to eq(%i[human-not-pedal throttle hand-pedal])
      end
    end
    context "e-" do
      it "is valid types" do
        expect(PropulsionType.valid_propulsion_types_for(:"e-scooter")).to eq(%i[throttle])
        expect(PropulsionType.valid_propulsion_types_for("personal-mobility")).to eq(%i[throttle])
      end
    end
    context "non-e" do
      it "is valid types" do
        expect(PropulsionType.valid_propulsion_types_for(:"non-e-scooter")).to eq(%i[human-not-pedal])
        expect(PropulsionType.valid_propulsion_types_for("non-e-skateboard")).to eq(%i[human-not-pedal])
      end
    end
  end

  describe "autocompleteable" do
    let(:motorized_hash) do
      {
        id: 10,
        text: "E-Vehicles (electric vehicles)",
        priority: 980,
        category: "propulsion",
        data: {priority: 980, slug: :motorized, search_id: "p_10"}
      }
    end
    describe "autocomplete_hash" do
      it "is the target" do
        expect(PropulsionType.send(:motorized_autocomplete_hash)).to match_hash_indifferently motorized_hash
        expect(PropulsionType.autocomplete_hashes.count).to eq 1
      end
    end
  end

  describe "names and translations" do
    let(:en_yaml) { YAML.safe_load_file(Rails.root.join("config", "locales", "en.yml"), permitted_classes: [Symbol]) }
    let(:enum_translations) do
      # For dumb historical reasons, slugs have dashes rather than underscores
      en_yaml.dig("en", "activerecord", "enums", "propulsion_type")
        .map { |k, v| [k.tr("_", "-"), v] }.to_h
    end
    it "has the same names as english translations" do
      expect(enum_translations).to match_hash_indifferently PropulsionType::NAMES
    end
  end
end
