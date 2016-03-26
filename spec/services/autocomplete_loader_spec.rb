require 'spec_helper'

describe AutocompleteLoader do
  describe 'reload' do
    it 'calls all the things' do
      autocomplete_loader = AutocompleteLoader.new
      expect(autocomplete_loader).to receive(:clear)
      expect(autocomplete_loader).to receive(:load_colors)
      expect(autocomplete_loader).to receive(:load_manufacturers)
      autocomplete_loader.reset
    end
  end
end
