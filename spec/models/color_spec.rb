require 'spec_helper'

describe Color do
  describe :validations do 
    it { should validate_presence_of :name }
    it { should validate_presence_of :priority }
    it { should validate_uniqueness_of :name }
    it { should have_many :paints }
  end

  describe :fuzzy_name_find do
    it "finds users by email address when the case doesn't match" do
      color = FactoryGirl.create(:color, name: "Poopy PANTERS")
      Color.fuzzy_name_find('poopy panters').should == color
    end
  end

  describe 'autocomplete_hash' do
    it 'returns what we want' do
      color = FactoryGirl.create(:color, name: 'blue', display: "<span class='sclr' style='background: #386ed2'></span>")
      result = color.autocomplete_hash
      expect(result.keys).to eq(['id', 'text', 'category', 'priority', 'data'])
      target_display = "#{color.display} <span class='sch_c'>#{color.name}</span>"
      expect(result['data']['display']).to eq target_display
    end
  end
end
