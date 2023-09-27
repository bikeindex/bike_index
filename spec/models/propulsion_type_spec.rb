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
    context "slug" do
      let(:name) { "other style" }
      it "tries to find the slug, given a name" do
        finder = PropulsionType.friendly_find(name)
        expect(finder.slug).to eq :"propulsion-other"
      end
    end
  end
end
