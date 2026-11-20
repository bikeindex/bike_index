require "rails_helper"

RSpec.describe Manufacturer, type: :model do
  it_behaves_like "autocomplete_hashable"
  it_behaves_like "short_nameable"

  describe "ensure_non_blocking_name" do
    before { FactoryBot.create(:color, name: "Purple") }
    context "name same as a color" do
      it "adds an error" do
        manufacturer = FactoryBot.build(:manufacturer, name: " pURple ")
        manufacturer.valid?
        expect(manufacturer.errors.full_messages.to_s).to match "same as a color"
      end
    end
    context "name includes a color" do
      it "adds no error" do
        manufacturer = FactoryBot.build(:manufacturer, name: "Purple bikes")
        manufacturer.valid?
        expect(manufacturer.errors.count).to eq 0
      end
    end
    context "name with single quote" do
      let(:manufacturer) { FactoryBot.build(:manufacturer, name: "stuff'") }
      it "is valid" do
        expect(manufacturer.valid?).to be_truthy
      end
    end
    context "name with double quote" do
      let(:manufacturer) { FactoryBot.build(:manufacturer, name: 'stuff"') }
      it "adds an error" do
        expect(manufacturer.valid?).to be_falsey
        expect(manufacturer.errors.full_messages.to_s).to match "quote"
      end
    end
  end

  describe "slug validation" do
    it "is invalid when a slug is all digits" do
      expect(FactoryBot.build(:manufacturer, name: "333")).not_to be_valid
      expect(FactoryBot.build(:manufacturer, name: "Foo (101)")).not_to be_valid
      expect(FactoryBot.build(:manufacturer, name: "Foo (101 Bikes)")).to be_valid
    end
  end

  describe "friendly_find" do
    it "finds manufacturers by their slug" do
      mnfg = FactoryBot.create(:manufacturer, name: "Poopy PANTERS")
      expect(Manufacturer.friendly_find("poopy panters")).to eq(mnfg)
    end
    it "finds by the slug and the previous slugs" do
      mnfg = FactoryBot.create(:manufacturer, name: "Kona Bicycle Company")
      expect(mnfg.slug).to eq "kona_bicycle_company"
      expect(mnfg.previous_slugs).to eq ["kona"]
      expect(Manufacturer.friendly_find("kona-bicycle-company")).to eq mnfg
      expect(Manufacturer.friendly_find("kona")).to eq mnfg
      expect(Manufacturer.friendly_find("Kona Bikes")).to eq mnfg

      kona = FactoryBot.create(:manufacturer, name: "Kona")
      expect(kona.previous_slugs).to eq []
      expect(Manufacturer.friendly_find("kona")).to eq kona
      expect(Manufacturer.friendly_find("Kona Bicycles")).to eq kona
      expect(Manufacturer.friendly_find("kona-bicycle-company")).to eq mnfg

      mnfg.update(name: "Kona Bicycle Works")
      expect(mnfg.reload.slug).to eq "kona_bicycle_works"
      expect(mnfg.previous_slugs).to eq %w[kona kona_bicycle_company]
      expect(Manufacturer.friendly_find("kona-bicycle-company")).to eq mnfg

      mnfg.update_columns(slug: "kona-bicycle-works", previous_slugs: %w[kona-bicycle-company])
      expect(Manufacturer.friendly_find("Kona Bicycle Works")).to eq mnfg
      expect(Manufacturer.friendly_find("kona-bicycle-company")).to eq mnfg
      mnfg.update(updated_at: Time.current)
      expect(mnfg.reload.slug).to eq "kona_bicycle_works"
      expect(mnfg.previous_slugs).to eq %w[kona-bicycle-company kona-bicycle-works kona]
    end
    it "removes Accell (because it's widespread mnfg)" do
      mnfg = FactoryBot.create(:manufacturer, name: "Poopy PANTERS")
      expect(Manufacturer.friendly_find("poopy panters Accell")).to eq(mnfg)
    end
    it "finds with dashes" do
      mnfg = FactoryBot.create(:manufacturer, name: "All City")
      expect(mnfg.secondary_name).to be_nil
      expect(mnfg.slug).to eq "all_city"
      expect(mnfg.previous_slugs).to eq []
      expect(Manufacturer.friendly_find("All-city ")&.id).to eq(mnfg.id)
    end
    it "finds in the secondary_slug" do
      mnfg = FactoryBot.create(:manufacturer, name: "S & M (S and M Bikes) ")
      expect(mnfg.secondary_name).to eq "S and M Bikes"
      expect(mnfg.secondary_slug).to eq "s_and_m"
      expect(Manufacturer.friendly_find("s & m")&.id).to eq mnfg.id
      expect(Manufacturer.find_by_secondary_slug("s_and_m")&.id).to eq mnfg.id
      expect(Manufacturer.friendly_find("s and m bikes")&.id).to eq mnfg.id
      expect(Manufacturer.friendly_find("s and m")&.id).to eq mnfg.id

      mnfg.update(name: "S & M (SandM)")
      expect(mnfg.reload.secondary_slug).to eq "sandm"
      expect(Manufacturer.friendly_find("s and m")).to be_nil
    end
    it "keeps the old name's slug when it was also the secondary slug" do
      mnfg = FactoryBot.create(:manufacturer, name: "Kona Bicycle Company (Kona)")
      expect([mnfg.secondary_slug, mnfg.previous_slugs]).to eq ["kona", ["kona"]]
      expect(mnfg.slug_collisions).to eq []

      mnfg.update(name: "Foo")
      expect(mnfg.reload.previous_slugs).to eq %w[kona kona_bicycle_company]
      expect(Manufacturer.friendly_find("Kona Bikes")).to eq mnfg
    end
    context "name of digits and a removed suffix, where the digits are another manufacturer's id" do
      let!(:other_manufacturer) { FactoryBot.create(:manufacturer) }
      let(:name) { "#{other_manufacturer.id} Bikes" }
      let!(:manufacturer) { FactoryBot.create(:manufacturer, name:) }

      it "finds each by its own identifier" do
        expect(manufacturer.to_param).to eq "#{other_manufacturer.id}_bikes"
        expect(manufacturer.previous_slugs).to eq []
        expect(Manufacturer.friendly_find(manufacturer.to_param)).to eq manufacturer
        expect(Manufacturer.friendly_find("#{other_manufacturer.id}-bikes")).to eq manufacturer
        expect(Manufacturer.friendly_find(name)).to eq manufacturer
        expect(Manufacturer.friendly_find(other_manufacturer.id.to_s)).to eq other_manufacturer
      end
    end
  end

  describe "slug_collisions" do
    let!(:kona_company) { FactoryBot.create(:manufacturer, name: "Kona Bicycle Company") }
    let!(:other) { FactoryBot.create(:manufacturer, name: "Cool Bikes") }

    it "is a slug that's another manufacturer's previous slug" do
      expect(Manufacturer.slug_collisions).to eq([])

      kona = FactoryBot.create(:manufacturer, name: "Kona")
      collision = {slug: "kona", manufacturer: {id: kona.id, name: "Kona"},
                   previous_slug_manufacturers: [{id: kona_company.id, name: "Kona Bicycle Company"}]}
      expect(Manufacturer.slug_collisions).to eq([collision])
      expect(kona.slug_collisions).to eq([collision])
      expect(kona_company.slug_collisions).to eq([collision])
      expect(other.slug_collisions).to eq([])
    end

    it "is a secondary slug that's another manufacturer's previous slug" do
      zebra = FactoryBot.create(:manufacturer, name: "Zebra (Kona)")
      expect(Manufacturer.slug_collisions).to eq([{slug: "kona", manufacturer: {id: zebra.id, name: "Zebra (Kona)"},
                                                   previous_slug_manufacturers: [{id: kona_company.id, name: "Kona Bicycle Company"}]}])
      expect(Manufacturer.friendly_find("kona bikes")).to eq zebra
    end

    it "is a previous slug several manufacturers share" do
      kona_works = FactoryBot.create(:manufacturer, name: "Kona Works")
      expect(Manufacturer.slug_collisions).to eq([{slug: "kona", manufacturer: nil,
                                                   previous_slug_manufacturers: [{id: kona_company.id, name: "Kona Bicycle Company"}, {id: kona_works.id, name: "Kona Works"}]}])
    end
  end

  describe "autocomplete_hash" do
    it "returns what we expect" do
      manufacturer = FactoryBot.create(:manufacturer)
      result = manufacturer.autocomplete_hash
      expect(result.keys).to eq(%i[id text category priority data])
      expect(result[:data][:slug]).to eq manufacturer.slug
      expect(result[:data][:search_id]).to eq("m_#{manufacturer.id}")
    end
  end

  describe "autocomplete_hash_category" do
    context "0 bikes or components" do
      it "returns 0" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:b_count) { 0 }
        allow(manufacturer).to receive(:c_count) { 0 }
        expect(manufacturer.send(:calculated_priority)).to eq(0)
      end
    end
    context "1 component" do
      it "returns 10" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:b_count) { 0 }
        allow(manufacturer).to receive(:c_count) { 2 }
        expect(manufacturer.send(:calculated_priority)).to eq(10)
      end
    end
    context "25 bikes and 50 components" do
      it "returns 15" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:b_count) { 24 }
        allow(manufacturer).to receive(:c_count) { 50 }
        expect(manufacturer.send(:calculated_priority)).to eq(14)
      end
    end
    context "1020 bikes" do
      it "returns 100" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:b_count) { 1020 }
        allow(manufacturer).to receive(:c_count) { 3 }
        expect(manufacturer.send(:calculated_priority)).to eq(100)
      end
    end
  end

  describe "friendly_find_id" do
    it "gets id from name" do
      manufacturer = FactoryBot.create(:manufacturer)
      result = Manufacturer.friendly_find_id(manufacturer.name)
      expect(result).to eq(manufacturer.id)
    end
    it "fails with nil" do
      result = Manufacturer.friendly_find_id("some stuff")
      expect(result).to be_nil
    end
  end

  describe "calculated_mnfg_name" do
    let(:manufacturer_other) { Manufacturer.other }
    let(:manufacturer) { Manufacturer.new(name: "Mnfg name") }
    it "returns the value of manufacturer_other if manufacturer is other" do
      expect(Manufacturer.calculated_mnfg_name(manufacturer, "Other manufacturer name")).to eq "Mnfg name"
      expect(Manufacturer.calculated_mnfg_name(manufacturer_other, "Other manufacturer name")).to eq("Other manufacturer name")
      expect(manufacturer.short_name).to eq "Mnfg name"
      expect(manufacturer.secondary_name).to be_nil
    end

    it "returns the name of the manufacturer if it isn't other" do
      expect(Manufacturer.calculated_mnfg_name(manufacturer, nil)).to eq("Mnfg name")
    end

    context "malicious" do
      let(:malicious_str) { '<a href="bad_site.js">stuff</a>' }
      it "removes bad things" do
        expect(Manufacturer.calculated_mnfg_name(manufacturer_other, malicious_str)).to eq "stuff"
      end
    end

    context "weird stuff" do
      let(:malicious_str) { "Sweet manufacturer <><>><\\" }
      let(:target) { "Sweet manufacturer &lt;&gt;&lt;&gt;&gt;&lt;\\" }
      it "encodes" do
        expect(Manufacturer.calculated_mnfg_name(manufacturer_other, malicious_str)).to eq target
      end
    end

    context "manufacturer with parens" do
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "SE Racing (S E Bikes)") }
      it "returns Just SE Bikes (and does it on save)" do
        expect(Manufacturer.calculated_mnfg_name(manufacturer, nil)).to eq "SE Racing"
        expect(manufacturer.reload.name).to eq "SE Racing (S E Bikes)"
        expect(manufacturer.short_name).to eq "SE Racing"
        expect(manufacturer.secondary_name).to eq "S E Bikes"
      end
    end
  end

  describe "set_calculated_attributes" do
    it "sets twitter_name" do
      manufacturer = Manufacturer.new(twitter_name: "@cool-thing")
      manufacturer.set_calculated_attributes
      expect(manufacturer.twitter_name).to eq "cool-thing"
    end
    it "sets logo source" do
      manufacturer = Manufacturer.new
      allow(manufacturer).to receive(:logo).and_return("http://example.com/logo.png")
      manufacturer.set_calculated_attributes
      expect(manufacturer.logo_source).to eq("manual")
    end

    it "doesn't overwrite logo source" do
      manufacturer = Manufacturer.new(logo_source: "something cool")
      allow(manufacturer).to receive(:logo).and_return("http://example.com/logo.png")
      manufacturer.set_calculated_attributes
      expect(manufacturer.logo_source).to eq("something cool")
    end

    it "empties" do
      manufacturer = Manufacturer.new(logo_source: "something cool", description: " ")
      manufacturer.set_calculated_attributes
      expect(manufacturer.logo_source).to be_nil
      expect(manufacturer.description).to be_nil
    end
  end

  describe "run_callback_job" do
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    it "happens on create" do
      expect { manufacturer }.to change(CallbackJobs::AfterManufacturerChangeJob.jobs, :count).by 1
    end

    it "happens when name is changed" do
      expect(manufacturer).to be_valid

      expect do
        manufacturer.update(frame_maker: true, description: "something", close_year: Time.current.year)
      end.to change(CallbackJobs::AfterManufacturerChangeJob.jobs, :count).by 0

      expect do
        manufacturer.update(name: "new special special name")
      end.to change(CallbackJobs::AfterManufacturerChangeJob.jobs, :count).by 1
    end

    it "does not happen when deleted" do
      expect(manufacturer).to be_valid

      expect do
        manufacturer.destroy
      end.to change(CallbackJobs::AfterManufacturerChangeJob.jobs, :count).by 0
    end
  end
end
