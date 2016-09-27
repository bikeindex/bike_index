require 'spec_helper'

describe HandlebarType do
  it_behaves_like 'friendly_slug_findable'
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_uniqueness_of :name }
    it { is_expected.to validate_presence_of :slug }
  end

  describe 'other' do
    context 'not-existing' do
      it 'creates it on first pass' do
        expect { HandlebarType.other }.to change(HandlebarType, :count).by(1)
      end
    end
    context 'existing' do
      before do
        HandlebarType.other
      end
      it 'does not create' do
        expect { HandlebarType.other }.to change(PropulsionType, :count).by(0)
      end
    end
  end

  describe 'flat' do
    context 'not-existing' do
      it 'creates it on first pass' do
        expect { HandlebarType.flat }.to change(HandlebarType, :count).by(1)
      end
    end
    context 'existing' do
      before do
        HandlebarType.flat
      end
      it 'does not create' do
        expect { HandlebarType.flat }.to change(PropulsionType, :count).by(0)
      end
    end
  end
end
