require "spec_helper"

describe PropulsionType do
  describe "normalized name" do
    let(:slug) { :insufflation }

    it "returns the slug's normalized name" do
      pt = PropulsionType.new(slug)
      expect(pt.name).to eq("Insufflation")
    end
  end

  describe "friendly_find" do
    context "slug" do
      let(:name) { "Other style" }
      it "tries to find the slug, given a name" do
        finder = PropulsionType.friendly_find(name)
        expect(finder.slug).to eq :"other-style"
      end
    end
  end
end
