# encoding: utf-8
require 'spec_helper'

describe Phonifyer do
  describe 'phonify' do
    it 'strips and remove non digits' do
      number = Phonifyer.phonify('(999) 899 - 999')
      expect(number).to eq('999899999')
    end
    it 'does not remove the country code' do
      number = Phonifyer.phonify('+91 80 4150 5583')
      expect(number).to eq('+91 8041505583')
    end
  end
end
