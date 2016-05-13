require 'spec_helper'

describe PublicImage do
  describe 'validations' do
    it { is_expected.to belong_to :imageable }
  end

  describe 'default_name' do
    it 'sets a default name from filename if not bike' do
      publicImage = PublicImage.new
      allow(publicImage).to receive(:imageable_type).and_return('Nope')
      allow(publicImage).to receive(:name).and_return('Boop')
      publicImage.default_name
      expect(publicImage.name).to eq('Boop')
    end

    it "returns the name of the manufacturer if it isn't other" do
      publicImage = PublicImage.new
      bike = FactoryGirl.create(:bike, year: 1969, frame_model: 'Hobo')
      allow(publicImage).to receive(:imageable_type).and_return('Bike')
      allow(publicImage).to receive(:imageable).and_return(bike)
      publicImage.default_name
      expect(publicImage.name).to eq("#{bike.title_string} #{bike.frame_colors.to_sentence}")
    end
  end

  describe 'lottapixel' do
    it "doesn't break" do
      lottapixel = File.open(File.join(Rails.root, 'spec', 'fixtures', 'hugeimg.png'))
      publicImage = FactoryGirl.build(:publicImage, image: lottapixel)
      publicImage.save
      expect(publicImage.id).to be_nil
      expect(publicImage.errors.full_messages.to_s.match('dimensions too large')).to be_truthy
    end
  end
end
