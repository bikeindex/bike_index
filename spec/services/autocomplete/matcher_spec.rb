require "rails_helper"

RSpec.describe Autocomplete::Matcher do
  let(:subject) { Autocomplete::Matcher }
  describe "search" do
    let(:color) { FactoryBot.create(:color, name: "Blue") }
    let!(:manufacturer1) { FactoryBot.create(:manufacturer, name: "S & M (S and M Bikes)", frame_maker: true) }
    let!(:manufacturer2) { FactoryBot.create(:manufacturer, name: "SE Bikes", frame_maker: true) }
    let!(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer2, primary_frame_color: color) }
    it "orders by priority" do
      Autocomplete::Loader.load_all
      result = subject.search
      expect(result.count).to eq 5
      expect(result.first["search_id"]).to eq
      expect(result.map { |i| i["search_id"] }).to eq("c_#{color.id}")

      # Autocomplete::Loader.send(:store_items, [Color.black.autocomplete_hash])
    end
  end

  describe "params_to_opts" do
    let(:default) { {offset: 0, limit: 4, categories: [], q_array: [], cache: true} }
    let(:default_cache_keys) { {cache_key: "autc:test:cache:all:", category_cache_key: "autc:test:cts:all:", interkeys: ["all:autc:test:cts:all:"]} }
    let(:default_target) { default.merge(default_cache_keys) }
    it "is the default plus cache keys" do
      expect(subject.send(:params_to_opts)).to eq default.merge(default_cache_keys)
      expect(subject.send(:params_to_opts, {page: "1"})).to eq default.merge(default_cache_keys)
      expect(subject.send(:params_to_opts, {page: "1", per_page: "5.0"})).to eq default.merge(default_cache_keys)
    end
    context "with different per_page and page params" do
      it "returns expected" do
        expect(subject.send(:params_to_opts, {per_page: "10"})).to eq default_target.merge(limit: 9)
        expect(subject.send(:params_to_opts, {page: "2", per_page: "7.0"})).to eq default_target.merge(limit: 13, offset: 7)
        expect(subject.send(:params_to_opts, {page: 20})).to eq default_target.merge(limit: 99, offset: 95)
      end
    end
    context "cache: false" do
      let(:target) { default_target.merge(cache: false) }
      it "default false" do
        expect(subject.send(:params_to_opts, {cache: "false"})).to eq target
      end
    end
    context "with a category and a query" do
      let(:target) do
        default.merge(categories: ["frame_mnfg"],
          q_array: ["black"],
          cache_key: "autc:test:cache:frame_mnfg:black",
          category_cache_key: "autc:test:cts:frame_mnfg:",
          interkeys: ["autc:test:cts:frame_mnfg:black"])
      end
      it "has the cache keys" do
        expect(subject.send(:params_to_opts, {q: "black", categories: ["frame_mnfg"]})).to eq target
      end
    end

    it "Makes category empty if it's all the categories" do
      result = subject.send(:params_to_opts, {categories: "colors, cycle_type, frame_mnfg,CMP_MNFG"})
      expect(result).to eq default_target
    end
  end

  describe "categories_array" do
    it "Returns an empty array from a string" do
      expect(subject.send(:categories_array)).to eq([])
      expect(subject.send(:categories_array, [])).to eq([])
      expect(subject.send(:categories_array, nil)).to eq([])
      expect(subject.send(:categories_array, " ")).to eq([])
    end
    it "returns an array from strings" do
      expect(subject.send(:categories_array, "colors")).to eq(%w[colors])
      expect(subject.send(:categories_array, "cycle_type,colors")).to eq(%w[colors cycle_type])
    end
  end

  describe "category_key_from_opts" do
    it "Gets the id for none" do
      expect(subject.send(:category_key_from_opts, [])).to eq "autc:test:cts:all:"
    end
    it "Gets the id for one" do
      expect(subject.send(:category_key_from_opts, ["cycle_type"])).to eq "autc:test:cts:cycle_type:"
    end

    it "Gets the id for all of them" do
      expect(subject.send(:category_key_from_opts, %w[colors frame_mnfg cmp_mnfg])).to eq "autc:test:cts:colorsframe_mnfgcmp_mnfg:"
    end
  end

  # TODO: test the matches
  # Also, test clearing the cache

  # describe "matches" do
  #   it 'With no params, gets all the matches, ordered by priority and name' do
  #     store_terms_fixture
  #     opts = { 'cache' => false }
  #     matches = Soulheart::Matcher.new(opts).matches
  #     expect(matches.count).to be == 5
  #   end

  #   it 'With no query but with categories, matches categories' do
  #     store_terms_fixture
  #     opts = { 'per_page' => 100, 'cache' => false, 'categories' => 'manufacturer' }
  #     matches = Soulheart::Matcher.new(opts).matches
  #     expect(matches.count).to eq(4)
  #     expect(matches[0]['text']).to eq('Brooks England LTD.')
  #     expect(matches[1]['text']).to eq('Sram')
  #   end

  #   it 'Gets the matches matching query and priority for one item in query, all categories' do
  #     store_terms_fixture
  #     opts = { 'per_page' => 100, 'q' => 'j', 'cache' => false }
  #     matches = Soulheart::Matcher.new(opts).matches
  #     expect(matches.count).to eq(3)
  #     expect(matches[0]['text']).to eq('Jamis')
  #   end

  #   it 'Gets the matches matching query and priority for one item in query, one category' do
  #     store_terms_fixture
  #     opts = { 'per_page' => 100, 'q' => 'j', 'cache' => false, 'categories' => 'manufacturer' }
  #     matches = Soulheart::Matcher.new(opts).matches
  #     expect(matches.count).to eq(2)
  #     expect(matches[0]['text']).to eq('Jannd')
  #   end

  #   it "Matches Chinese" do
  #     store_terms_fixture
  #     opts = { 'q' => "中国" }
  #     matches = Soulheart::Matcher.new(opts).matches
  #     expect(matches.length).to eq(1)
  #     expect(matches[0]['text']).to eq("中国佛山 李小龙")
  #   end

  #   it 'Gets pages and uses them' do
  #     Soulheart::Loader.new.clear(true)
  #     # Pagination wrecked my mind, hence the multitude of tests]
  #     items = [
  #       { 'text' => 'First item', 'priority' => '11000' },
  #       { 'text' => 'First atom', 'priority' => '11000' },
  #       { 'text' => 'Second item', 'priority' => '1999' },
  #       { 'text' => 'Third item', 'priority' => 1900 },
  #       { 'text' => 'Fourth item', 'priority' => 1800 },
  #       { 'text' => 'Fifth item', 'priority' => 1750 },
  #       { 'text' => 'Sixth item', 'priority' => 1700 },
  #       { 'text' => 'Seventh item', 'priority' => 1699 }
  #     ]
  #     loader = Soulheart::Loader.new
  #     loader.delete_categories
  #     loader.load(items)
  #     page1 = Soulheart::Matcher.new('per_page' => 1, 'cache' => false).matches
  #     expect(page1[0]['text']).to eq('First atom')

  #     page2 = Soulheart::Matcher.new('per_page' => 1, 'page' => 2, 'cache' => false).matches
  #     expect(page2[0]['text']).to eq('First item')

  #     page2 = Soulheart::Matcher.new('per_page' => 1, 'page' => 3, 'cache' => false).matches
  #     expect(page2.count).to eq(1)
  #     expect(page2[0]['text']).to eq('Second item')

  #     page3 = Soulheart::Matcher.new('per_page' => 2, 'page' => 3, 'cache' => false).matches
  #     expect(page3[0]['text']).to eq('Fourth item')
  #     expect(page3[1]['text']).to eq('Fifth item')
  #   end

  #   it "gets +1 and things with changed normalizer function" do
  #     Soulheart.normalizer = ''
  #     require 'soulheart'
  #     items = [
  #       { 'text' => '+1'},
  #       { 'text' => '-1'},
  #       { 'text' => '( ͡↑ ͜ʖ ͡↑)' },
  #       { 'text' => '100' },
  #     ]
  #     loader = Soulheart::Loader.new
  #     loader.delete_categories
  #     loader.load(items)
  #     plus1 = Soulheart::Matcher.new('q' => '+', 'cache' => false).matches
  #     expect(plus1.count).to eq(1)
  #     expect(plus1[0]['text']).to eq('+1')

  #     minus1 = Soulheart::Matcher.new('q' => '-', 'cache' => false).matches
  #     expect(minus1[0]['text']).to eq('-1')

  #     donger = Soulheart::Matcher.new('q' => '(', 'cache' => false).matches
  #     expect(donger[0]['text']).to eq('( ͡↑ ͜ʖ ͡↑)')

  #     Soulheart.normalizer = Soulheart.default_normalizer
  #     require 'soulheart'
  #   end
  # end
end
