require 'spec_helper'

describe PropulsionType do
  it_behaves_like 'friendly_slug_findable'
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_uniqueness_of :name }
  end

  describe 'foot_pedal' do
    context 'not-existing' do
      it 'creates it on first pass' do
        expect { PropulsionType.foot_pedal }.to change(PropulsionType, :count).by(1)
      end
    end
    context 'existing' do
      before do
        PropulsionType.foot_pedal
      end
      it 'does not create' do
        expect { PropulsionType.foot_pedal }.to change(PropulsionType, :count).by(0)
      end
    end
  end
end
