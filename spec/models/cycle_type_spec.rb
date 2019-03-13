require 'spec_helper'

describe CycleType do
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
end
