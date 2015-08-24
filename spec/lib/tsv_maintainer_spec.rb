require 'spec_helper'

describe TsvMaintainer do
  
  describe :blacklist_ids do
    it "gets and sets the ids" do 
      TsvMaintainer.reset_blacklist_ids([1, 1, 2, 4, 'https://bikeindex.org/admin/bikes/6'])
      expect(TsvMaintainer.blacklist).to eq(['1', '2', '4', '6'])
    end
  end

  describe :blacklist_include do 
    it 'checks if blacklist includes something' do 
      TsvMaintainer.reset_blacklist_ids([1010101, 2, 4, 6])
      expect(TsvMaintainer.blacklist_include?('http://bikeindex.org/bikes/1010101/edit')).to be_true
      expect(TsvMaintainer.blacklist_include?(7)).to be_false
    end
  end

  describe :update_tsv_info do 
    it "updates tsv info" do 
      t = Time.now
      TsvMaintainer.reset_tsv_info('current_stolen_bikes.tsv', t)
      expect(TsvMaintainer.tsvs).to eq([{filename: 'current_stolen_bikes.tsv', updated_at: "#{t.to_i}", description: 'Approved Stolen bikes'}])
    end
  end

end