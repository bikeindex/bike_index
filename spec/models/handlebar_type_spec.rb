require "rails_helper"

RSpec.describe HandlebarType, type: :model do
  describe "normalized name" do
    let(:slug) { :horizontal }

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

    it "returns horizontal for its names and former slugs" do
      ["horizontal", "Riser", " FLAT ", :flat, " BMX ", :bmx, "BMX style"].each do
        expect(HandlebarType.friendly_find(it).slug).to eq :horizontal
      end
    end

    context "slug" do
      let(:name) { "Horizontal facing " }
      it "tries to find the slug, given a name" do
        finder = HandlebarType.friendly_find(name)
        expect(finder.slug).to eq :horizontal
      end
    end
  end

  describe "api_slug" do
    it "returns flat for horizontal" do
      expect(HandlebarType.api_slug("horizontal")).to eq "flat"
      expect(HandlebarType.api_slug("drop_bar")).to eq "drop_bar"
      expect(HandlebarType.api_slug(nil)).to be_nil
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
