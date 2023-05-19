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
        finder = CycleType.friendly_find(name)
        expect(finder.slug).to eq :trailer
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
end
