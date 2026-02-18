require "rails_helper"

RSpec.describe FrameMaterial, type: :model do
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

  describe "names and translations" do
    let(:en_yaml) { YAML.safe_load_file(Rails.root.join("config", "locales", "en.yml"), permitted_classes: [Symbol]) }
    let(:enum_translations) do
      en_yaml.dig("en", "activerecord", "enums", "frame_material")
    end
    it "has the same names as english translations" do
      expect(enum_translations).to have_attributes FrameMaterial::NAMES
    end
  end
end
