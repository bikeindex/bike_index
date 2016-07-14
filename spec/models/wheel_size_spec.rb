require 'spec_helper'

describe WheelSize do
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_presence_of :priority }
    it { is_expected.to validate_presence_of :description }
    it { is_expected.to validate_presence_of :iso_bsd }
    it { is_expected.to validate_uniqueness_of :description }
    it { is_expected.to validate_uniqueness_of :iso_bsd }
  end

  describe 'popularity' do
    it 'returns the popularities word of the wheel size' do
      wheel_size = WheelSize.new(priority: 1)
      expect(wheel_size.popularity).to eq('Standard')
      wheel_size.priority = 4
      expect(wheel_size.popularity).to eq('Rare')
    end
  end

  describe 'find_id_by_iso_bsd' do
    context 'string iso_bsd' do
      it 'returns the id' do
        wheel_size = FactoryGirl.create(:wheel_size, iso_bsd: 622)
        expect(WheelSize.id_for_bsd("\n622 ")).to eq wheel_size.id
      end
    end
    context 'unknown number' do
      it 'returns nil' do
        expect(WheelSize.id_for_bsd('6220')).to be_nil
      end
    end
  end
end
