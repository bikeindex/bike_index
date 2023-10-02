require "rails_helper"

RSpec.describe Autocomplete::Matcher do
  describe "search_params" do
    let(:default) { {offset: 0, limit: 4, categories: [], q_array: [], cache: true} }
    let(:default_cache_keys) { {cache_key: "autc:test:cache:all:", category_cache_key: "autc:test:cts:all:", interkeys: ["all:autc:test:cts:all:"]} }
    it "is the default plus cache keys" do
      expect(described_class.send(:search_params)).to eq default.merge(default_cache_keys)
      expect(described_class.send(:search_params, {page: "1"})).to eq default.merge(default_cache_keys)
      expect(described_class.send(:search_params, {page: "1", per_page: "5.0"})).to eq default.merge(default_cache_keys)
    end
    context "with different per_page and page params" do
      let(:default_target) { default.merge(default_cache_keys) }
      it "returns expected" do
        expect(described_class.send(:search_params, {per_page: "10"})).to eq default_target.merge(limit: 9)
        expect(described_class.send(:search_params, {page: "2", per_page: "7.0"})).to eq default_target.merge(limit: 13, offset: 7)
        expect(described_class.send(:search_params, {page: 20})).to eq default_target.merge(limit: 99, offset: 95)
      end
    end
    context "cache: false" do
      let(:target) { default.merge(cache: false, cache_key: "autc:test:cache:all:") }
      it "default false" do
        expect(described_class.send(:search_params, {cache: "false"})).to eq target
      end
    end
    context "with a category and a query" do
      let(:target) do
        default.merge(categories: ["manufacturer"],
          q_array: ["black"],
          cache_key: "autc:test:cache:manufacturer:black",
          category_cache_key: "autc:test:cts:manufacturer:",
          interkeys: ["autc:test:cts:manufacturer:black"])
      end
      it "has the cache keys" do
        expect(described_class.send(:search_params, {q: "black", categories: ["manufacturer"]})).to eq target
      end
    end

    # TODO: Once loader is working
    xit "Makes category empty if it's all the categories" do
      Autocomplete::Loader.reset_categories(%w[cool test])
      result = described_class.send(:search_params, {categories: "cool, test"})
      expect(result).to eq default_params
    end
  end

  describe "categories_array" do
    it "Returns an empty array from a string" do
      expect(described_class.send(:categories_array)).to eq([])
      expect(described_class.send(:categories_array, [])).to eq([])
      expect(described_class.send(:categories_array, nil)).to eq([])
      expect(described_class.send(:categories_array, " ")).to eq([])
    end
    it "returns an array from strings" do
      expect(described_class.send(:categories_array, "something")).to eq(%w[something])
      expect(described_class.send(:categories_array, "something,else")).to eq(%w[else something])
    end
  end

  describe "category_key_from_opts" do
    it "Gets the id for one" do
      expect(described_class.send(:category_key_from_opts, [])).to eq "autc:test:cts:all:"
    end
    it "Gets the id for one" do
      expect(described_class.send(:category_key_from_opts, ["some_category"])).to eq "autc:test:cts:some_category:"
    end

    # TODO: Once loader is working
    xit "Gets the id for all of them" do
      Soulheart::Loader.new.reset_categories(%w[cool test boo])
      expect(described_class.send(:category_key_from_opts, %w[boo cool test])).to eq("")
    end
  end

  # describe "categories_string" do
  #   it 'Does all if none' do
  #     Soulheart::Loader.new.reset_categories(%w(cool test))
  #     matcher = Soulheart::Matcher.new('categories' => '')
  #     expect(matcher.categories_string).to eq('all')
  #   end
  #   it 'Correctly concats a string of categories' do
  #     Soulheart::Loader.new.reset_categories(['cool', 'some_category', 'another cat', 'z9', 'stuff'])
  #     matcher = Soulheart::Matcher.new('categories' => 'some_category, another cat, z9')
  #     expect(matcher.categories_string).to eq('another catsome_categoryz9')
  #   end
  # end

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

  #   it "Doesn't duplicate when matching both alias and the normal term" do
  #     store_terms_fixture
  #     opts = { 'q' => 'stadium' }
  #     matches = Soulheart::Matcher.new(opts).matches
  #     expect(matches.length).to eq(5)
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
