require 'spec_helper'

RSpec.shared_examples 'friendly_slug_findable' do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryGirl.create model_sym }

  describe 'callbacks' do
    it 'calls set slug before create' do
      obj = FactoryGirl.build(model_sym, name: 'something cool and things&')
      expect(obj).to receive :set_slug
      obj.save
    end
  end

  describe 'set_slug' do
    context 'name' do
      it 'slugs it' do
        obj = FactoryGirl.build(model_sym, name: 'something cool and things&')
        obj.slug = nil
        obj.set_slug
        expect(obj.slug).to eq Slugifyer.slugify('something cool and things&')
      end
    end
    context 'existing' do
      it "doesn't overwrite" do
        obj = FactoryGirl.build model_sym
        obj.slug = 'something cool'
        obj.set_slug
        expect(obj.slug).to eq 'something cool'
      end
    end
  end

  describe 'to_param' do
    it 'returns slug' do
      subject.slug = 'cool slug name'
      expect(subject.to_param).to eq 'cool slug name'
    end
  end

  describe 'friendly_find' do
    before do
      expect(instance).to be_present
    end

    context 'integer_slug' do
      it 'finds by id' do
        expect(subject.class.friendly_find(instance.id.to_s)).to eq instance
      end
    end

    context 'non-integer slug' do
      it 'finds by the slug' do
        expect(subject.class.friendly_find(" #{instance.name}")).to eq instance
      end
    end
  end
end
