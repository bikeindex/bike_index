require "rails_helper"

RSpec.describe CycleType, type: :model do
  describe "normalized name" do
    let(:slug) { :trailer }

    it "returns the slug's normalized name" do
      ht = CycleType.new(slug)
      expect(ht.name).to eq("Bike Trailer")
    end
  end

  describe "friendly_find" do
    context "slug" do
      let(:name) { "Trailer " }
      it "tries to find the slug, given a name" do
        expect(CycleType.find_sym(name)).to eq :trailer
        expect(CycleType.find_sym(:trailer)).to eq :trailer
        finder = CycleType.friendly_find(name)
        expect(finder.slug).to eq :trailer
      end
    end
    context "name" do
      let(:name) { "Cargo Bike (front storage)" }
      it "tries to find the slug, given a name" do
        expect(CycleType.find_sym(name)).to eq :cargo
        expect(CycleType.find_sym(8)).to eq :cargo
        expect(CycleType.find_sym("8 ")).to eq :cargo
        expect(CycleType.find_sym("CARGO BIKE")).to eq :cargo
        finder = CycleType.friendly_find(name)
        expect(finder.slug).to eq :cargo
      end
    end
  end

  describe "enum vals" do
    it "has all different values" do
      values = CycleType::SLUGS.values
      expect(values.uniq).to eq values
    end
  end

  describe "select_options" do
    let(:trad_bike) { ['Traditional Bike (2 wheels, 1 seat, no motor)', 'bike'] }
    it "has the values" do
      expect(CycleType.select_options).to include(['Bike', 'bike'])
      expect(CycleType.select_options(traditional_bike: true)).to include(trad_bike)
      expect(CycleType.select_options(traditional_bike: true).uniq.count).to eq 21
    end
  end

  describe "slugify" do
    CycleType::SLUGS.keys.each do |slug|
      it "finds" do
        expect(Slugifyer.slugify(slug)).to eq slug.to_s
      end
    end
  end

  describe "slug_hash_lowecase" do
    it "makes a hash" do
      expect(CycleType.slug_translation_hash_lowercase_short["cargo"]).to eq "cargo bike"
    end
  end

  describe "find" do
    it "finds" do
      expect(CycleType.find(3).as_json).to eq CycleType.new(:tricycle).as_json
    end
  end

  describe "not_cycle_drivetrain?" do
    it "is falsey" do
      expect(CycleType.not_cycle_drivetrain?(:bike)).to be_falsey
      %w[tandem tricycle recumbent cargo tall-bike penny-farthing
        cargo-rear cargo-trike cargo-trike-rear pedi-cab].each do |vtype|
          expect(CycleType.not_cycle_drivetrain?(vtype)).to be_falsey
          # Coincidentally, also this:
          expect(CycleType.not_cycle?(vtype)).to be_falsey
          expect(CycleType.front_and_rear_wheels?(vtype)).to be_truthy
        end
    end
    context "trail-behind" do
      let(:vtype) { "trail-behind" }
      it "is truthy" do
        expect(CycleType.not_cycle_drivetrain?(vtype)).to be_truthy
        expect(CycleType.not_cycle?(vtype)).to be_falsey
        expect(CycleType.front_and_rear_wheels?(vtype)).to be_falsey
      end
    end
    context "e-scooter" do
      let(:vtype) { "e-scooter" }
      it "is truthy" do
        expect(CycleType.not_cycle_drivetrain?(vtype)).to be_truthy
        expect(CycleType.not_cycle?(vtype)).to be_truthy
        expect(CycleType.front_and_rear_wheels?(vtype)).to be_truthy
      end
    end
    context "non-e-skateboard" do
      let(:vtype) { "non-e-skateboard" }
      it "is truthy" do
        expect(CycleType.not_cycle_drivetrain?(vtype)).to be_truthy
        expect(CycleType.not_cycle?(vtype)).to be_truthy
        expect(CycleType.front_and_rear_wheels?(vtype)).to be_falsey
      end
    end
    context "unicycle" do
      let(:vtype) { "unicycle" }
      it "is truthy" do
        expect(CycleType.not_cycle_drivetrain?(vtype)).to be_truthy
        expect(CycleType.not_cycle?(vtype)).to be_falsey
        expect(CycleType.front_and_rear_wheels?(vtype)).to be_falsey
      end
    end
    context "wheelchair" do
      let(:vtype) { "wheelchair" }
      it "is truthy" do
        expect(CycleType.not_cycle_drivetrain?(vtype)).to be_truthy
        expect(CycleType.not_cycle?(vtype)).to be_truthy
        expect(CycleType.front_and_rear_wheels?(vtype)).to be_falsey
      end
    end
    context "stroller" do
      let(:vtype) { "stroller" }
      it "is truthy" do
        expect(CycleType.not_cycle_drivetrain?(vtype)).to be_truthy
        expect(CycleType.not_cycle?(vtype)).to be_truthy
        expect(CycleType.front_and_rear_wheels?(vtype)).to be_falsey
      end
    end
    context "trailer" do
      let(:vtype) { "trailer" }
      it "is truthy" do
        expect(CycleType.not_cycle_drivetrain?(vtype)).to be_truthy
        expect(CycleType.not_cycle?(vtype)).to be_falsey
        expect(CycleType.front_and_rear_wheels?(vtype)).to be_falsey
      end
    end
  end

  describe "priority" do
    # These are calculated based on rough rankings from a count of matching bikes:
    # CycleType.slugs.map { |s| "#{s}: #{Bike.where(cycle_type: s).count}" }
    it "high priorities" do
      expect(CycleType.find(0).priority).to eq 950
      expect(CycleType.find(11).priority).to eq 940
      expect(CycleType.new("e-scooter").priority).to eq 930
    end
    it "is 920 for a variety" do
      expect(CycleType.new("tricycle").priority).to eq 920
      expect(CycleType.new("tandem").priority).to eq 920
      expect(CycleType.new("recumbent").priority).to eq 920
      expect(CycleType.new("personal-mobility").priority).to eq 920
    end
    it "is 900 for some others" do
      expect(CycleType.new("cargo").priority).to eq 900
      expect(CycleType.new("non-e-scooter").priority).to eq 900
      expect(CycleType.new("unicycle").priority).to eq 900
    end
  end

  describe "autocomplete_hash" do
    let(:target) do
      {
        id: 0,
        text: "Bike",
        priority: 950,
        category: "cycle_type",
        data: {priority: 950, slug: :bike, search_id: "v_0"}
      }
    end
    let(:cycle_type) { CycleType.find(0) }
    it "is target" do
      expect_hashes_to_match(cycle_type.autocomplete_hash, target)
      target_result_hash = target.except(:data).merge(target[:data])
      expect(cycle_type.autocomplete_result_hash).to eq target_result_hash.as_json
    end
    context "all autocomplete_hashes" do
      it "has text" do
        autocomplete_hashes = CycleType.all.map { |c| c.autocomplete_hash }
        expect(autocomplete_hashes.map { |h| h[:text] }).to_not include(nil)
      end
    end
  end
end
