# encoding: utf-8
require 'spec_helper'

describe Phonifyer do
  describe 'phonify' do
    context 'no country code' do
      it 'strips and remove non digits' do
        number = Phonifyer.phonify('(999) 899 - 999')
        expect(number).to eq('999899999')
      end
    end
    context 'country code' do
      it 'does not remove the country code' do
        number = Phonifyer.phonify('+91 80 4150 5583')
        expect(number).to eq('+91 8041505583')
      end
    end
  end

  describe 'display' do
    context 'no country code' do
      it 'dots' do
        expect(Phonifyer.display('(999) 899 - 999')).to eq('999.899.999')
      end
    end
    context 'country code' do
      it 'dots' do
        expect(Phonifyer.display('+91 8041505583')).to eq('+91 804.150.5583')
      end
    end
    context 'nil' do
      it "doesn't error" do
        expect(Phonifyer.display(nil)).to eq(nil)
      end
    end
  end
end
