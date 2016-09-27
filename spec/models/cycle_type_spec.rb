require 'spec_helper'

describe CycleType do
  it_behaves_like 'friendly_slug_findable'
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_uniqueness_of :name }
    it { is_expected.to validate_presence_of :slug }
    it { is_expected.to validate_uniqueness_of :slug }
  end

  describe 'bike' do
    context 'not-existing' do
      it 'creates it on first pass' do
        expect { CycleType.bike }.to change(CycleType, :count).by(1)
      end
    end
    context 'existing' do
      before do
        CycleType.bike
      end
      it 'does not create' do
        expect { CycleType.bike }.to change(PropulsionType, :count).by(0)
      end
    end
  end
end
