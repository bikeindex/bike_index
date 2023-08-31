require "rails_helper"

RSpec.describe AutocompleteLoader do
  describe "reload" do
    it "calls all the things" do
      autocomplete_loader = AutocompleteLoader.new
      expect(autocomplete_loader).to receive(:clear)
      expect(autocomplete_loader).to receive(:load_colors)
      expect(autocomplete_loader).to receive(:load_manufacturers)
      expect(autocomplete_loader).to receive(:load_cycle_types)
      autocomplete_loader.reset
    end
  end
end
