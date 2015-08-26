require 'spec_helper'

describe TsvMaintainer do
  
  describe :blacklist_ids do
    it "gets and sets the ids" do 
      TsvMaintainer.reset_blacklist_ids([1, 1, 2, 4, 'https://bikeindex.org/admin/bikes/6'])
      expect(TsvMaintainer.blacklist).to eq(['1', '2', '4', '6'])
    end
    it "doesn't break if it's empty" do 
      TsvMaintainer.reset_blacklist_ids([])
      expect(TsvMaintainer.blacklist).to eq([])
    end
  end

  describe :blacklist_include do 
    it 'checks if blacklist includes something' do 
      TsvMaintainer.reset_blacklist_ids([1010101, 2, 4, 6])
      expect(TsvMaintainer.blacklist_include?('http://bikeindex.org/bikes/1010101/edit')).to be_true
      expect(TsvMaintainer.blacklist_include?(7)).to be_false
    end
  end

  describe 'tsv info' do 
    it "updates tsv info and returns with indifferent access" do 
      t = Time.now
      TsvMaintainer.reset_tsv_info('current_stolen_bikes.tsv', t)
      tsv = TsvMaintainer.tsvs[0]
      expect(tsv[:updated_at]).to eq("#{t.to_i}")
      expect(tsv['path']).to eq("current_stolen_bikes.tsv")
    end

    it "returns the way we want" do 
      t = Time.now 
      TsvMaintainer.reset_tsv_info('https://files.bikeindex.org/uploads/tsvs/approved_current_stolen_bikes.tsv', t)
      tsv = TsvMaintainer.tsvs.first
      expect(tsv[:filename]).to eq('approved_current_stolen_bikes.tsv')
      expect(tsv[:description]).to eq('Stolen bikes (without blacklisted bikes)')
    end
  end

end