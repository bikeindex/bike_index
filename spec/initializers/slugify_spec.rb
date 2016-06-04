# encoding: utf-8
require 'spec_helper'

describe Slugifyer do
  describe 'book_slug' do
    it 'removes special characters and downcase' do
      slug = Slugifyer.book_slug("Surly's Cross-check bike (small wheel)")
      expect(slug).to eq('surly_s_cross_check_small_wheel')
    end

    it 'removes bikes and bicycles, because people just put them in everything' do
      slug = Slugifyer.book_slug('Cross-check Singlespeed BicyclE')
      expect(slug).to eq('cross_check_singlespeed')
    end

    it 'removes diacritics and bicycles, because people just put them in everything' do
      slug = Slugifyer.book_slug('paké rum runner')
      expect(slug).to eq('pake_rum_runner')
    end

    it 'changes + to plus for URL safety, and Trek uses + to differentiate' do
      slug = Slugifyer.book_slug('L100+ Lowstep BLX')
      expect(slug).to eq('l100plus_lowstep_blx')
    end
  end

  describe 'manufacturer' do
    it 'removes works rivendell' do
      slug = Slugifyer.manufacturer('Rivendell Bicycle Works')
      expect(slug).to eq('rivendell')
    end
    it 'removes frameworks for legacy' do
      slug = Slugifyer.manufacturer('Legacy Frameworks')
      expect(slug).to eq('legacy')
    end
    it 'removes bicycle company for Kona' do
      slug = Slugifyer.manufacturer('Kona Bicycle Company')
      expect(slug).to eq('kona')
    end
    it 'does not remove WorkCycles' do
      slug = Slugifyer.manufacturer('WorkCycles')
      expect(slug).to eq('workcycles')
    end
    it 'does not remove haibike' do
      slug = Slugifyer.manufacturer('Haibike (Currietech)')
      expect(slug).to eq('haibike')
    end
    it 'does not remove worksman' do
      slug = Slugifyer.manufacturer('Worksman Cycles')
      expect(slug).to eq('worksman')
    end
    it 'removes parens from EAI' do
      slug = Slugifyer.manufacturer('EAI (Euro Asia Imports)')
      expect(slug).to eq('eai')
    end
  end
end
