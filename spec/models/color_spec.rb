require 'spec_helper'

describe Color do
  it_behaves_like 'friendly_name_findable'
  it_behaves_like 'autocomplete_hashable'
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_presence_of :priority }
    it { is_expected.to validate_uniqueness_of :name }
    it { is_expected.to have_many :paints }
  end

  describe 'friendly_find' do
    it "finds users by email address when the case doesn't match" do
      color = FactoryGirl.create(:color, name: 'Poopy PANTERS')
      expect(Color.friendly_find('poopy panters')).to eq(color)
    end
  end

  describe 'autocomplete_hash' do
    it 'returns what we want' do
      color = FactoryGirl.create(:color, name: 'blue', display: '#386ed2')
      result = color.autocomplete_hash
      expect(result.keys).to eq(%w(id text category priority data))
      expect(result['data']['display']).to eq color.display
      expect(result['data']['search_id']).to eq("c_#{color.id}")
    end
  end

  describe 'update_display_format' do
    context 'with a background color' do
      it 'removes the extra display information to just return a color' do
        color = FactoryGirl.create(:color, name: 'blue', display: "<span class='sclr' style='background: #386ed2'></span>")
        color.reload
        color.update_display_format
        expect(color.display).to eq('#386ed2')
      end
    end
    context 'without a background color' do
      it 'makes it white with full transparency' do
        color = FactoryGirl.create(:color, name: 'blue', display: "<span class='sclr'>stckrs</span>")
        color.reload
        color.update_display_format
        expect(color.display).to be_nil
      end
    end
  end
end
