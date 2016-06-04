require 'spec_helper'

describe SerialNormalizer do
  describe 'normalize' do
    it 'normalizes i o 5 2 z and b' do
      serial = 'bobs-catzio'
      result = SerialNormalizer.new(serial: serial).normalized
      expect(result).to eq('8085 CAT210')
    end
    it 'normalizes -_+= and multiple spaces' do
      serial = 's>e-r--i+a_l'
      result = SerialNormalizer.new(serial: serial).normalized
      expect(result).to eq('5 E R 1 A 1')
    end
    it 'remove leading zeros and ohs' do
      serial = '00O38675971596'
      result = SerialNormalizer.new(serial: serial).normalized
      expect(result).to eq('38675971596')
    end
  end

  describe 'normalized_segments' do
    it 'makes normalized segments' do
      segments = SerialNormalizer.new(serial: 'some + : serial').normalized_segments
      expect(segments.count).to eq(2)
      expect(segments[0]).to eq('50ME')
    end
    it 'returns nil if serial is absent' do
      segments = SerialNormalizer.new(serial: 'absent').normalized_segments
      expect(segments).to be_nil
    end
  end

  describe 'save_segments' do
    it 'saves normalized segments with the bike_id and not break if we resave' do
      bike = FactoryGirl.create(:bike)
      SerialNormalizer.new(serial: 'some + : serial').save_segments(bike.id)
      expect(NormalizedSerialSegment.where(bike_id: bike.id).count).to eq(2)
    end

    it 'does not save absent segments' do
      bike = FactoryGirl.create(:bike)
      SerialNormalizer.new(serial: 'absent').save_segments(bike.id)
      expect(NormalizedSerialSegment.where(bike_id: bike.id).count).to eq(0)
    end

    it 'rewrites the segments if we save them a second time' do
      bike = FactoryGirl.create(:bike)
      SerialNormalizer.new(serial: 'some + : serial').save_segments(bike.id)
      expect(NormalizedSerialSegment.where(bike_id: bike.id).count).to eq(2)
      SerialNormalizer.new(serial: 'another + : THING').save_segments(bike.id)
      segments = NormalizedSerialSegment.where(bike_id: bike.id)
      expect(segments.count).to eq(2)
      expect(segments[1].segment).to eq('AN0THER')
    end

    it 'does not make any if the bike is an example bike' do
      bike = FactoryGirl.create(:bike)
      bike.update_attributes(example: true)
      SerialNormalizer.new(serial: 'some + : serial').save_segments(bike.id)
      expect(NormalizedSerialSegment.where(bike_id: bike.id).count).to eq(0)
    end
  end
end
