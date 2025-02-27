require "rails_helper"

RSpec.describe Autocomplete::Loader do
  let(:subject) { Autocomplete::Loader }
  let(:category_count_for_1_item) { 16 } # Because of the combinatorial categories
  # WTF CircleCI - you're shitting the bed.
  # manufacturer.count == 1 tests are failing, because manufacturers are sticking around
  before { Manufacturer.delete_all }

  describe "load_all" do
    let!(:color) { Color.black }
    let!(:manufacturer) { Manufacturer.other }
    it "stores", :flaky do
      expect(CycleType.all.count).to eq 21
      expect(Manufacturer.count).to eq 1
      expect(Color.count).to eq 1
      expect(PropulsionType.autocomplete_hashes.count).to eq 1
      subject.clear_redis
      total_count = subject.load_all
      expect(total_count).to eq 24 * category_count_for_1_item
      info = subject.info
      # IDK, db0 seems to cause problems
      expect(info.keys - [:db0]).to match_array(%i[category_keys cache_keys used_memory used_memory_peak])
      expect(info[:category_keys]).to eq 3648
      expect(info[:cache_keys]).to eq 0
    end

    context "passing individual types" do
      it "stores the passed kind", :flaky do
        expect(CycleType.all.count).to eq 21
        expect(Manufacturer.count).to eq 1
        expect(Color.count).to eq 1
        subject.clear_redis
        color_count = subject.load_all(["Color"])
        expect(color_count).to eq category_count_for_1_item

        manufacturer_count = subject.load_all(["Manufacturer"])
        expect(manufacturer_count).to eq category_count_for_1_item

        cycle_type_count = subject.load_all(["CycleType"])
        expect(cycle_type_count).to eq 21 * category_count_for_1_item
      end
    end
  end

  describe "clean_data" do
    it "sets the color category, priority and normalizes term" do
      item = {text: "  FooBar", category: "colors"}
      target = {
        priority: 100,
        term: "foobar",
        category: "colors",
        data: {text: "  FooBar", category: "colors"}
      }
      expect(subject.send(:clean_hash, item)).to eq target
    end

    it "doesn't overwrite the submitted params (including the data-text)" do
      item = {
        text: "Cool ",
        priority: "50",
        category: "frame_mnfg",
        data: {
          text: " Cspan",
          id: 199,
          category: "frame_mnfg"
        }
      }
      result = subject.send(:clean_hash, item)
      expect(result[:term]).to eq("cool")
      expect(result[:priority]).to eq(50)
      expect(result[:data][:id]).to eq(199)
      expect(result[:data][:text]).to eq(" Cspan")
      expect(result[:category]).to eq("frame_mnfg")
      expect(result[:data][:category]).to eq("frame_mnfg")
    end

    it "raises argument error if no text is passed" do
      expect do
        subject.send(:clean_hash, {name: "stuff"})
      end.to raise_error(/must have/i)
    end

    it "raises argument error if the category doesn't match" do
      expect do
        subject.send(:clean_hash, {text: "stuff", category: "gooble"})
      end.to raise_error(/category/i)
    end

    context "manufacturer" do
      let(:input) { {id: 1006, text: "sixthreezero", category: "frame_mnfg", priority: 41, data: {slug: "sixthreezero", priority: 41, search_id: "m_1006"}} }
      let(:target) do
        {
          category: "frame_mnfg", priority: 41.0, term: "sixthreezero",
          data: {
            text: "sixthreezero", category: "frame_mnfg", slug: "sixthreezero", priority: 41, search_id: "m_1006", id: 1006
          }
        }
      end
      it "returns the result" do
        expect(subject.send(:clean_hash, input)).to match_hash_indifferently target
      end
    end

    context "color" do
      let(:input) { {id: 12, text: "Yellow or Gold", category: "colors", priority: 1000, data: {priority: 1000, display: "#fff44b", search_id: "c_12"}} }
      let(:target) { {category: "colors", priority: 1000.0, term: "yellow or gold", data: {text: "Yellow or Gold", category: "colors", priority: 1000, display: "#fff44b", search_id: "c_12", id: 12}} }
      it "returns the result" do
        expect(subject.send(:clean_hash, input)).to match_hash_indifferently target
      end
    end
  end

  describe "prefixes_for_phrase" do
    it "Obeys passed stop words" do
      target = %w[l lo loc lock t th the i in ink p pe pen]
      expect(subject.send(:prefixes_for_phrase, "lock the ink pen")).to eq target
      stub_const("Autocomplete::STOP_WORDS", ["the"])
      target_no_the = %w[l lo loc lock i in ink p pe pen]
      expect(subject.send(:prefixes_for_phrase, "lock the ink pen")).to eq target_no_the
    end

    it "Obeys default stop words" do
      prefixes1 = %w[k kn kni knic knick knicks]
      expect(subject.send(:prefixes_for_phrase, "knicks")).to eq(prefixes1)

      prefixes2 = %w[t te tes test testi testin th thi this]
      expect(subject.send(:prefixes_for_phrase, "testin' this")).to eq(prefixes2)

      prefixes3 = %w[t te tes test]
      expect(subject.send(:prefixes_for_phrase, "test test")).to eq(prefixes3)

      prefixes4 = %w[s so sou soul soulm soulma soulmat soulmate]
      expect(subject.send(:prefixes_for_phrase, "SoUlmATE")).to eq(prefixes4)

      # prefixes5 = %w[测 测试 测试中 测试中文 t te tes test] # Should be this, but we're ignoring characters :(
      prefixes5 = %w[t te tes test]
      expect(subject.send(:prefixes_for_phrase, "测试中文 test")).to eq(prefixes5)

      prefixes6 = %w[t te tet teth tethe tether]
      expect(subject.send(:prefixes_for_phrase, "tether")).to eq(prefixes6)
    end
  end

  describe "store_item" do
    let(:item_hash) do
      {
        id: 55, text: "Brompton Bicycle", category: "frame_mnfg", priority: 100,
        data: {slug: "brompton", priority: 100, search_id: "m_55"}
      }
    end
    let(:item) { subject.send(:clean_hash, item_hash) }
    let(:target) { item_hash.except(:data).merge(item_hash[:data]) }
    it "adds an item, adds prefix scopes, adds category" do
      subject.clear_redis
      subject.send(:store_item, item)

      result = RedisPool.conn { |r| r.hget(Autocomplete.items_data_key, "brompton bicycle") }
      expect(JSON.parse(result)).to match_hash_indifferently target

      prefix = "#{Autocomplete.category_key("frame_mnfg")}brom"
      prefixed_result = RedisPool.conn { |r| r.zrange(prefix, 0, -1) }
      expect(prefixed_result[0]).to eq("brompton bicycle")
    end
  end

  describe "load_items" do
    context "colors" do
      let!(:color) { FactoryBot.create(:color, display: "#333") }
      let(:target_color) { {category: "colors", display: "#333", id: color.id, priority: 1000, search_id: "c_#{color.id}", text: color.name} }
      let(:normalized_name) { Autocomplete.normalize(color.name) }
      it "loads colors" do
        subject.clear_redis
        expect(Color.count).to eq 1
        count = subject.send(:store_items, [color.autocomplete_hash])
        expect(count).to eq category_count_for_1_item

        result = RedisPool.conn { |r| r.hget(Autocomplete.items_data_key, normalized_name) }
        expect(JSON.parse(result)).to match_hash_indifferently target_color

        prefix = "#{Autocomplete.category_key("colors")}col"
        prefixed_result = RedisPool.conn { |r| r.zrange(prefix, 0, -1) }
        expect(prefixed_result[0]).to eq normalized_name
      end
    end
    context "manufacturers" do
      let!(:manufacturer1) { FactoryBot.create(:manufacturer, frame_maker: true) }
      let!(:brompton) { FactoryBot.create(:manufacturer, name: "Brompton", frame_maker: true) }
      let!(:manufacturer3) { FactoryBot.create(:manufacturer, frame_maker: false) }
      let!(:bike) { FactoryBot.create(:bike, manufacturer: brompton) }
      let(:target_manufacturer) { {text: "Brompton", category: "frame_mnfg", slug: "brompton", priority: 10, search_id: "m_#{brompton.id}", id: brompton.id} }
      it "stores terms by priority and adds categories for each possible category combination" do
        expect(manufacturer1.reload.priority).to eq 0
        expect(manufacturer3.reload.priority).to eq 0
        brompton.update_column :priority, 10

        subject.clear_redis

        result = subject.send(:store_items, Manufacturer.all.map { |m| m.autocomplete_hash })
        expect(result).to eq category_count_for_1_item * 3

        cat_prefixed = RedisPool.conn do |r|
          r.zrange("#{Autocomplete.category_key("frame_mnfg")}br", 0, -1)
        end
        expect(cat_prefixed).to eq(["brompton"])

        item_json = RedisPool.conn do |r|
          r.hmget(Autocomplete.items_data_key, Autocomplete.normalize(brompton.name))
        end
        expect(item_json.count).to eq 1
        item = JSON.parse(item_json.first)
        expect(item).to match_hash_indifferently target_manufacturer
      end
    end
  end
end
