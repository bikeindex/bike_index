require 'spec_helper'

describe HandlebarType do
  describe "normalized name" do
    let(:slug) { :bmx }

    it "returns the slug's normalized name" do
      ht = HandlebarType.new(slug)
      expect(ht.name).to eq("BMX style")
    end
  end

  describe "friendly_find" do
    it "returns nil" do
      expect(HandlebarType.friendly_find(" ")).to be_nil
    end

    context "slug" do
      let(:name) { "Bmx " }
      it "tries to find the slug, given a name" do
        finder = HandlebarType.friendly_find(name)
        expect(finder.slug).to eq :bmx
      end
    end
  end
end
