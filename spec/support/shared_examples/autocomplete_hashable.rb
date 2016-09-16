require 'spec_helper'

RSpec.shared_examples 'autocomplete_hashable' do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryGirl.create model_sym }

  describe 'autocomplete_result_hash' do
    it 'it is the expected hash' do
      result = instance.autocomplete_result_hash
      instance.autocomplete_hash.each do |key, value|
        if key == 'data'
          value.each { |k, v| expect(result[k]).to eq v }
        else
          expect(result[key]).to eq value
        end
      end
      expect(result['search_id']).to be_present
    end
  end
end
