require "rails_helper"

RSpec.describe Autocomplete::Loader do
  let(:subject) { Autocomplete::Loader }
  let(:category_count_for_1_item) { 7 } # Because of the combinatorial categories

  describe "load_all" do
    let!(:color) { Color.black }
    let!(:manufacturer) { Manufacturer.other }
    it "stores" do
      expect(CycleType.all.count).to eq 20
      expect(Manufacturer.count).to eq 1
      expect(Color.count).to eq 1
      total_count = subject.load_all
      expect(total_count).to eq 22 * category_count_for_1_item
    end
  end

  describe "clean_data" do
    it 'sets the color category, priority and normalizes term' do
      item = { text: '  FooBar', category: "colors" }
      target = {
        priority: 100,
        term: "foobar",
        category: "colors",
        data: {text: "  FooBar", category: "colors" }
      }
      expect(subject.send(:clean_hash, item)).to eq target
    end

    it "doesn't overwrite the submitted params (including the data-text)" do
      item = {
        text: 'Cool ',
        priority: '50',
        category: 'frame_mnfg',
        data: {
          text: ' Cspan',
          id: 199,
          category: 'frame_mnfg'
        }
      }
      result = subject.send(:clean_hash, item)
      expect(result[:term]).to eq('cool')
      expect(result[:priority]).to eq(50)
      expect(result[:data][:id]).to eq(199)
      expect(result[:data][:text]).to eq(' Cspan')
      expect(result[:category]).to eq('frame_mnfg')
      expect(result[:data][:category]).to eq('frame_mnfg')
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
        expect_hashes_to_match(subject.send(:clean_hash, input), target)
      end
    end

    context "color" do
      let(:input) { {id: 12, text: "Yellow or Gold", category: "colors", priority: 1000, data: {priority: 1000, display: "#fff44b", search_id: "c_12"}} }
      let(:target) { {category: "colors", priority: 1000.0, term: "yellow or gold", data: {text: "Yellow or Gold", category: "colors", priority: 1000, display: "#fff44b", search_id: "c_12", id: 12}} }
      it "returns the result" do
        expect_hashes_to_match(subject.send(:clean_hash, input), target)
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
    it 'adds an item, adds prefix scopes, adds category' do
      subject.clear_redis(true)
      subject.send(:store_item, item)

      result = Autocomplete.redis { |r| r.hget(Autocomplete.results_hashes_id, "brompton bicycle") }
      expect_hashes_to_match(JSON.parse(result), target)

      prefix = "#{Autocomplete.category_id("frame_mnfg")}brom"
      prefixed_result = Autocomplete.redis { |r| r.zrange(prefix, 0, -1) }
      expect(prefixed_result[0]).to eq('brompton bicycle')
    end
  end

  describe "load_items" do
    context "colors" do
      let!(:color) { FactoryBot.create(:color, display: "#333") }
      let(:target_color) { {category: "colors", display: "#333", id: color.id, priority: 1000, search_id: "c_#{color.id}", text: color.name} }
      let(:normalized_name) { Autocomplete.normalize(color.name) }
      it "loads colors" do
        subject.clear_redis(true)
        expect(Color.count).to eq 1
        count = subject.send(:store_items, [color.autocomplete_hash])
        expect(count).to eq category_count_for_1_item

        result = Autocomplete.redis { |r| r.hget(Autocomplete.results_hashes_id, normalized_name) }
        expect_hashes_to_match(JSON.parse(result), target_color)

        prefix = "#{Autocomplete.category_id("colors")}col"
        prefixed_result = Autocomplete.redis { |r| r.zrange(prefix, 0, -1) }
        expect(prefixed_result[0]).to eq normalized_name
      end
    end
    context "manufacturers" do
      let!(:manufacturer1) { FactoryBot.create(:manufacturer, frame_maker: true) }
      let!(:manufacturer2) { FactoryBot.create(:manufacturer, name: "Brompton", frame_maker: true) }
      let!(:manufacturer3) { FactoryBot.create(:manufacturer, frame_maker: false) }
      let!(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer2) }
      it "stores terms by priority and adds categories for each possible category combination" do
        expect(manufacturer1.reload.autocomplete_hash_priority).to eq 0
        expect(manufacturer2.reload.autocomplete_hash_priority).to eq 10
        expect(manufacturer3.reload.autocomplete_hash_priority).to eq 0

        subject.clear_redis(true)
        result = subject.send(:store_items, Manufacturer.all.map { |m| m.autocomplete_hash })
        expect(result).to eq category_count_for_1_item * 3

        # items = []
        # file = File.read('spec/fixtures/multiple_categories.json')
        # file.each_line { |l| items << JSON.parse(l) }
        # loader = Soulheart::Loader.new
        # loader.clear(true)
        # redis = loader.redis
        # loader.delete_categories
        # loader.load(items)

        cat_prefixed = Autocomplete.redis do |r|
          r.zrange("#{Autocomplete.category_id('frame manufacturermanufacturer')}brom", 0, -1)
        end
        pp cat_prefixed
        expect(cat_prefixed.count).to eq(1)
        expect(redis.smembers(loader.categories_id).count).to be > 3
        prefixed = redis.zrange "#{loader.category_id('all')}bro", 0, -1
        expect(prefixed.count).to eq(2)
        expect(prefixed[0]).to eq('brompton bicycle')
      end
    end

  #   it "stores terms by priority and doesn't add run categories if none are present" do
  #     items = [
  #       { 'text' => 'cool thing', 'category' => 'AWESOME' },
  #       { 'text' => 'Sweet', 'category' => ' awesome' }
  #     ]
  #     loader = Soulheart::Loader.new
  #     loader.clear(true)
  #     redis = loader.redis
  #     loader.delete_categories
  #     loader.load(items)
  #     expect(redis.smembers(loader.category_combos_id).count).to eq(1)
  #   end
  end

  # describe :clear do
  #   context 'remove_results false (default)' do
  #     it "deletes everything, but leaves the cache" do
  #       items = [
  #         {'text' => 'Brompton Bicycle', 'category' => 'Gooble'},
  #         {'text' => 'Surly Bicycle', 'category' => 'Bluster'},
  #         {"text" => "Defaulted"}
  #       ]
  #       search_opts = {'categories' => 'Bluster, Gooble', 'q' => 'brom'}

  #       loader = Soulheart::Loader.new

  #       redis = loader.redis
  #       loader.load(items)
  #       redis = loader.redis
  #       expect(redis.hget(loader.results_hashes_id, 'brompton bicycle').length).to be > 0
  #       expect((redis.zrange "#{loader.category_id('gooble')}brom", 0, -1)[0]).to eq("brompton bicycle")
  #       expect((redis.zrange "#{loader.category_id('blustergooble')}brom", 0, -1)[0]).to eq("brompton bicycle")

  #       matches1 = Soulheart::Matcher.new(search_opts).matches
  #       expect(matches1[0]['text']).to eq("Brompton Bicycle")

  #       loader.clear
  #       expect(redis.hget(loader.results_hashes_id, 'brompton bicycle')).to_not be_nil
  #       prefixed = redis.zrange "#{loader.category_id('gooble')}brom", 0, -1
  #       expect(prefixed).to be_empty
  #       expect(redis.zrange "#{loader.category_id('blustergooble')}brom", 0, -1).to be_empty
  #       expect(redis.smembers(loader.categories_id).include?('gooble')).to be_false

  #       matches2 = Soulheart::Matcher.new(search_opts).matches
  #       expect(matches2[0]['text']).to eq("Brompton Bicycle")
  #       expect(Soulheart::Matcher.new(search_opts.merge("cache" => false)).matches).to be_empty
  #     end
  #   end
  #   context 'remove_results true' do
  #     it 'removes everything including the results' do
  #       items = [
  #         {'text' => 'Brompton Bicycle', 'category' => 'Gooble'},
  #         {'text' => 'Surly Bicycle', 'category' => 'Bluster'},
  #         {"text" => "Defaulted"}
  #       ]
  #       search_opts = {'categories' => 'Bluster, Gooble', 'q' => 'brom'}

  #       loader = Soulheart::Loader.new

  #       redis = loader.redis
  #       loader.load(items)
  #       redis = loader.redis
  #       expect(redis.hget(loader.results_hashes_id, 'brompton bicycle').length).to be > 0
  #       expect(redis.zrange "#{loader.no_query_id(loader.category_id('gooble'))}", 0, -1).to_not be_nil
  #       # expect((redis.zrange "#{loader.no_query_id('gooble')}", 0, -1)[0]).to eq("brompton bicycle")
  #       expect((redis.zrange "#{loader.category_id('gooble')}brom", 0, -1)[0]).to eq("brompton bicycle")
  #       expect((redis.zrange "#{loader.category_id('blustergooble')}brom", 0, -1)[0]).to eq("brompton bicycle")

  #       matches1 = Soulheart::Matcher.new(search_opts).matches
  #       expect(matches1[0]['text']).to eq("Brompton Bicycle")

  #       loader.clear(true)
  #       expect(redis.zrange "#{loader.no_query_id(loader.category_id('gooble'))}", 0, -1).to eq([])
  #       expect(redis.hget(loader.results_hashes_id, 'brompton bicycle')).to be_nil
  #     end
  #   end
  # end
  # describe :clear_cache do
  #   it 'removes the cache' do
  #     items = [
  #       {'text' => 'Brompton Bicycle', 'category' => 'Gooble'},
  #       {'text' => 'Surly Bicycle', 'category' => 'Bluster'},
  #       {"text" => "Defaulted"}
  #     ]
  #     search_opts = {'categories' => 'Bluster, Gooble', 'q' => 'brom'}

  #     loader = Soulheart::Loader.new

  #     redis = loader.redis
  #     loader.load(items)
  #     redis = loader.redis
  #     expect(redis.hget(loader.results_hashes_id, 'brompton bicycle').length).to be > 0
  #     expect(redis.zrange "#{loader.no_query_id(loader.category_id('gooble'))}", 0, -1).to_not be_nil
  #     # expect((redis.zrange "#{loader.no_query_id('gooble')}", 0, -1)[0]).to eq("brompton bicycle")
  #     expect((redis.zrange "#{loader.category_id('gooble')}brom", 0, -1)[0]).to eq("brompton bicycle")
  #     expect((redis.zrange "#{loader.category_id('blustergooble')}brom", 0, -1)[0]).to eq("brompton bicycle")

  #     matches1 = Soulheart::Matcher.new(search_opts).matches
  #     expect(matches1[0]['text']).to eq("Brompton Bicycle")

  #     loader.clear_cache
  #     expect(redis.zrange "#{loader.no_query_id(loader.category_id('gooble'))}", 0, -1).to eq([])
  #     expect((redis.zrange "#{loader.category_id('gooble')}brom", 0, -1)[0]).to eq("brompton bicycle")
  #     expect((redis.zrange "#{loader.category_id('blustergooble')}brom", 0, -1)[0]).to eq("brompton bicycle")
  #   end
  # end
end
