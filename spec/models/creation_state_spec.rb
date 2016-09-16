require 'spec_helper'

RSpec.describe CreationState, type: :model do
  describe 'validations' do
    it { is_expected.to belong_to :bike }
    it { is_expected.to belong_to :organization }
    it { is_expected.to validate_presence_of :bike_id }
    it { is_expected.to validate_presence_of :origin } # Because neither specified
    it { is_expected.to validate_presence_of :organization_id } # Because neither specified
  end

  describe 'origin' do
    context 'unknown origin' do
      it 'ignores an unknown origin and does not save' do
        creation_state = CreationState.new(origin: 'SOMEwhere', bike_id: 2)
        expect(creation_state.save).to be_falsey
        expect(creation_state.origin).to be_nil
      end
    end
    context 'known origin' do
      let(:origin) { CreationState.origins.last }
      it 'uses the origin' do
        creation_state = CreationState.new(origin: origin)
        creation_state.ensure_allowed_origin
        expect(creation_state.origin).to eq origin
      end
    end
    it 'has a before_save callback for ensure_allowed_origin' do
      expect(CreationState._validation_callbacks.select { |cb| cb.kind.eql?(:before) }
        .map(&:raw_filter).include?(:ensure_allowed_origin)).to be_truthy
    end
  end
end
