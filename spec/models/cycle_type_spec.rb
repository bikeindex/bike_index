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

  describe "slugify" do
    CycleType::SLUGS.keys.each do |slug|
      it "finds" do
        expect(Slugifyer.slugify(slug)).to eq slug.to_s
      end
    end
  end

  describe "find" do
    it "finds" do
      expect(CycleType.find(3).as_json).to eq CycleType.new(:tricycle).as_json
    end
  end

  describe "autocomplete_hash" do
    let(:target) do
      {
        id: 0,
        text: "Bike",
        priority: 900,
        category: "cycle_type",
        data: {priority: 900, slug: :bike, search_id: "v_0"}
      }
    end
    let(:cycle_type) { CycleType.find(0) }
    it "is target" do
      expect_hashes_to_match(cycle_type.autocomplete_hash, target)
      target_result_hash = target.except(:data).merge(target[:data])
      expect(cycle_type.autocomplete_result_hash).to eq target_result_hash.as_json
    end
  end
end
