require "spec_helper"

describe FrameMaterial do
  describe "name" do
    let(:enum) { :organic }
    subject { FrameMaterial.new(enum) }

    it "returns the normalized enum name" do
      expect(subject.name).to eq(FrameMaterial::NAMES[enum])
    end
  end

  describe "friendly_find" do
    it "returns nil" do
      expect(FrameMaterial.friendly_find(" ")).to be_nil
    end
    context "steel" do
      let(:name) { "Steel " }
      it "tries to find the slug, given a name" do
        expect(FrameMaterial.friendly_find(name).name).to eq "Steel"
      end
    end
    context "carbon or composite" do
      let(:name) { "Carbon or composite" }
      it "tries to find the slug, given a name" do
        expect(FrameMaterial.friendly_find(name).name).to eq "Carbon or composite"
      end
    end
  end
end
