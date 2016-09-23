require 'spec_helper'

RSpec.describe Creation, type: :model do
  describe 'validations' do
    it { is_expected.to have_one :bike }
    it { is_expected.to belong_to :creator }
    it { is_expected.to belong_to :organization }
    it { is_expected.to belong_to :location }
    it { is_expected.to validate_presence_of :creator_id }
  end

  describe 'origin' do
    context 'unknown origin' do
      it 'ignores an unknown origin and does not save' do
        creation = Creation.new(origin: 'SOMEwhere', bike_id: 2)
        creation.ensure_permitted_origin
        expect(creation.origin).to be_nil
      end
    end
    context 'known origin' do
      let(:origin) { Creation.origins.last }
      it 'uses the origin' do
        creation = Creation.new(origin: origin)
        creation.ensure_permitted_origin
        expect(creation.origin).to eq origin
      end
    end
    it 'has a before_save callback for ensure_permitted_origin' do
      expect(Creation._validation_callbacks.select { |cb| cb.kind.eql?(:before) }
        .map(&:raw_filter).include?(:ensure_permitted_origin)).to be_truthy
    end
  end
end
