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
        expect(CycleType.send(:secondary_names_for, CycleType::NAMES[:cargo].downcase)).to eq(["cargo bike", "front storage"])
        expect(CycleType.find_sym(name)).to eq :cargo
        expect(CycleType.find_sym(8)).to eq :cargo
        expect(CycleType.find_sym("8 ")).to eq :cargo
        expect(CycleType.find_sym("CARGO BIKE")).to eq :cargo
        finder = CycleType.friendly_find(name)
        expect(finder.slug).to eq :cargo
        expect(finder.name).to eq "Cargo Bike (front storage)"
        expect(finder.short_name).to eq "Cargo Bike"
      end
    end
    context "EPAMD" do
      let(:cycle_type) { CycleType.new("personal-mobility") }

      let(:name_and_secondary_names) do
        ["personal-mobility", "e-personal mobility (epamd, e-skateboard, segway, e-unicycle, etc)",
          "e-personal mobility", "epamd", "e-skateboard", "segway", "e-unicycle"]
      end
      it "finds by various names" do
        expect(cycle_type.id).to eq 18
        expect(CycleType.send(:names_and_secondary_names)[17]).to eq name_and_secondary_names
        expect(cycle_type.name).to match "e-Skateboard"
        expect(CycleType.friendly_find("E-Skateboard")&.id).to eq cycle_type.id
        expect(CycleType.friendly_find("EPAMD")&.id).to eq cycle_type.id
        expect(CycleType.friendly_find(" epamd ")&.id).to eq cycle_type.id
        expect(CycleType.friendly_find("personal_mobility")&.id).to eq cycle_type.id
      end
    end
    context "other cargo varieties" do
      let(:cycle_type) { CycleType.new("cargo-trike") }
      let(:cargo_trike_secondaries) { ["cargo tricycle", "trike with front storage", "christiania bike"] }
      it "returns target" do
        expect(CycleType.send(:secondary_names_for, CycleType::NAMES[:"cargo-trike"].downcase))
          .to eq cargo_trike_secondaries
        expect(CycleType.friendly_find("cargo-trike")&.id).to eq cycle_type.id
        expect(CycleType.friendly_find("cargo tricycle")&.id).to eq cycle_type.id
        expect(CycleType.friendly_find("christiania bike")&.id).to eq cycle_type.id
        # NOTE: this is a previous name that might still be around from API clients
        expect(CycleType.friendly_find("cargo tricycle (front storage)")&.id).to eq cycle_type.id
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
    let(:trad_bike) { ["Traditional Bike (2 wheels, 1 seat, pedals)", "bike"] }
    it "has the values" do
      expect(CycleType.select_options).to include(["Bike", "bike"])
      expect(CycleType.select_options(traditional_bike: true)).to include(trad_bike)
      expect(CycleType.select_options(traditional_bike: true).uniq.count).to eq 22
    end
  end

  describe "slugify" do
    CycleType::SLUGS.keys.each do |slug|
      it "finds" do
        expect(Slugifyer.slugify(slug)).to eq slug.to_s
      end
    end
  end

  describe "slug_translation" do
    it "returns short name" do
      expect(CycleType.slug_translation("cargo")).to eq "Cargo Bike (front storage)"
      expect(CycleType.slug_translation_hash_lowercase_short["cargo"]).to eq "cargo bike"
    end

    context "with invalid name" do
      it "raises error for slug_translation" do
        expect { CycleType.slug_translation("asdfasdf") }.to raise_error(I18n::MissingTranslationData)
      end
      it "slug_translation_hash_lowercase_short returns nothing" do
        expect(CycleType.slug_translation_hash_lowercase_short["asdfasdf"]).to be_nil
      end
    end
  end

  describe "find" do
    it "finds" do
      expect(CycleType.find(3).as_json).to eq CycleType.new(:tricycle).as_json
    end
  end

  describe "names and translations" do
    let(:en_yaml) { YAML.safe_load_file(Rails.root.join("config", "locales", "en.yml"), permitted_classes: [Symbol]) }
    let(:cycle_type_translations) do
      # For dumb historical reasons, slugs have dashes rather than underscores
      en_yaml.dig("en", "activerecord", "enums", "cycle_type")
        .map { |k, v| [k.tr("_", "-"), v] }.to_h
    end
    it "has the same names as english translations" do
      expect(cycle_type_translations.except("traditional-bike")).to match_hash_indifferently CycleType::NAMES
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
      expect(cycle_type.autocomplete_hash).to match_hash_indifferently target
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
