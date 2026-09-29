require "rails_helper"

RSpec.describe HandlebarType, type: :model do
  describe "normalized name" do
    let(:slug) { :flat }

    it "returns the slug's normalized name" do
      ht = HandlebarType.new(slug)
      expect(ht.name).to eq("Flat or riser (horizontal facing)")
    end
  end

  describe "friendly_find" do
    it "returns nil" do
      expect(HandlebarType.friendly_find(" ")).to be_nil
    end

    it "returns nil" do
      expect(HandlebarType.friendly_find("not-known-type")).to be_nil
    end

    it "returns flat for the removed bmx" do
      expect(HandlebarType.friendly_find(" BMX ").slug).to eq :flat
      expect(HandlebarType.friendly_find(:bmx).slug).to eq :flat
      expect(HandlebarType.friendly_find("BMX style").slug).to eq :flat
    end

    context "slug" do
      let(:name) { "Horizontal facing " }
      it "tries to find the slug, given a name" do
        finder = HandlebarType.friendly_find(name)
        expect(finder.slug).to eq :flat
      end
    end
  end

  describe "names and translations" do
    let(:en_yaml) { YAML.safe_load_file(Rails.root.join("config", "locales", "en.yml"), permitted_classes: [Symbol]) }
    let(:enum_translations) do
      en_yaml.dig("en", "activerecord", "enums", "handlebar_type")
    end
    it "has the same names as english translations" do
      expect(enum_translations).to match_hash_indifferently HandlebarType::NAMES
    end
  end
end
