require 'spec_helper'

describe FrameMaterial do
  it_behaves_like 'friendly_slug_findable'
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_uniqueness_of :name }
    it { is_expected.to validate_presence_of :slug }
    it { is_expected.to validate_uniqueness_of :slug }
  end

  describe 'steel' do
    context 'not-existing' do
      it 'creates it on first pass' do
        expect { FrameMaterial.steel }.to change(FrameMaterial, :count).by(1)
      end
    end
    context 'existing' do
      before do
        FrameMaterial.steel
      end
      it 'does not create' do
        expect { FrameMaterial.steel }.to change(PropulsionType, :count).by(0)
      end
    end
  end
end
