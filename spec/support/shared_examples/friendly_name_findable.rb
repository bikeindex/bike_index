require 'spec_helper'

RSpec.shared_examples 'friendly_name_findable' do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryGirl.create model_sym }

  describe 'friendly_find' do
    before do
      expect(instance).to be_present
    end
    context 'integer_slug' do
      it 'finds by id' do
        expect(subject.class.friendly_find(instance.id.to_s)).to eq instance
      end
    end

    context 'not integer slug' do
      it 'finds by the name' do
        expect(subject.class.friendly_find(" #{instance.name} ")).to eq instance
      end
    end
  end
end
