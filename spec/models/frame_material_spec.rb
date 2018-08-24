require 'spec_helper'

describe FrameMaterial do
  it_behaves_like 'friendly_slug_findable'

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
