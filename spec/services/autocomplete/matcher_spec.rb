require "rails_helper"

RSpec.describe Autocomplete::Matcher do
  let(:subject) { Autocomplete::Matcher }
  describe "search" do
    let(:color) { FactoryBot.create(:color, name: "Blue") }
    let!(:manufacturer1) { FactoryBot.create(:manufacturer, name: "Bike Friday", frame_maker: true) }
    let!(:manufacturer2) { FactoryBot.create(:manufacturer, name: "BH Bikes (Beistegui Hermanos)", frame_maker: true) }
    let!(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer2, primary_frame_color: color) }
    # NOTE: This tests a bunch of different parts of the system, which is why it's a pretty long test
    it "orders by priority" do
      expect(color.autocomplete_hash[:priority]).to eq 1000
      expect(CycleType.new(:tandem).autocomplete_hash[:priority]).to eq 920
      expect(manufacturer1.reload.autocomplete_hash[:priority]).to eq 0
      manufacturer2 = Manufacturer.find(bike.manufacturer_id) # Unmemoize b_count
      expect(manufacturer2.reload.calculated_priority).to eq 10
      manufacturer2.reload.update(updated_at: Time.current)
      expect(manufacturer2.reload.autocomplete_hash[:priority]).to eq 10
      Autocomplete::Loader.clear_redis
      Autocomplete::Loader.load_all
      opts = subject.params_to_opts
      pp opts
      # Check that it's not in cache (verifies that clear_redis works correctly, etc)
      expect(subject.send(:not_in_cache?, opts[:cache_key])).to be_truthy
      result = subject.search(nil, opts)
      expect(result.count).to eq 5
      color_sid = "c_#{color.id}"
      expect(result.first["search_id"]).to eq color_sid
      cycle_type_search_ids = ["v_0", "v_11", "v_16"]
      expect(result.map { |i| i["search_id"] }).to eq([color_sid] + ["p_10"] + cycle_type_search_ids)
      # And now, the response is the in the cache
      expect(subject.send(:not_in_cache?, opts[:cache_key])).to be_falsey

      # Query result
      opts_query = subject.params_to_opts(q: "b", per_page: 10)
      pp opts_query
      # Isn't in cache
      expect(subject.send(:not_in_cache?, opts_query[:cache_key])).to be_truthy
      result_query = subject.search(nil, opts_query)
      expect(result_query.count).to eq 10
      target_search_ids = [color_sid, "v_0", "v_11", "v_6", "v_8", "v_22", "v_9", "v_14", "m_#{manufacturer2.id}", "m_#{manufacturer1.id}"]
      pp target_search_ids.sort, result_query.map { |i| i["search_id"] }.sort
      expect(result_query.map { |i| i["search_id"] }).to eq target_search_ids
      # But it is in cache after the search
      expect(subject.send(:not_in_cache?, opts_query[:cache_key])).to be_falsey

      # Testing caching - colors have higher priority, so they should come first
      Autocomplete::Loader.send(:store_items, [Color.black.autocomplete_hash])
      # Because caching, it is still the same as it was before
      expect(subject.search(nil, opts)).to eq result
      # Getting the second page, skips the first two colors
      paginated_opts = subject.params_to_opts(page: 2, per_page: 4)
      result_paginated = subject.search(nil, paginated_opts)
      expect(result_paginated.map { |i| i["search_id"] }).to eq(%w[v_16 v_18 v_5 v_1])
    end
  end

  describe "params_to_opts" do
    let(:default) { {offset: 0, limit: 4, categories: [], q_array: [], cache: true} }
    let(:default_cache_keys) { {cache_key: "autc:test:cache:all:", category_cache_key: "autc:test:cts:all:", interkeys: ["autc:test:noq:autc:test:cts:all:"]} }
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
      result = subject.send(:params_to_opts, {categories: "colors, cycle_type, Propulsion,frame_mnfg,CMP_MNFG"})
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
end
