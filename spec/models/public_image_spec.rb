require 'spec_helper'

describe PublicImage do
  describe 'validations' do
    it { is_expected.to belong_to :imageable }
  end

  describe 'default_name' do
    it 'sets a default name from filename if not bike' do
      public_image = PublicImage.new
      allow(public_image).to receive(:imageable_type).and_return('Nope')
      allow(public_image).to receive(:name).and_return('Boop')
      public_image.default_name
      expect(public_image.name).to eq('Boop')
    end

    it "returns the name of the manufacturer if it isn't other" do
      public_image = PublicImage.new
      bike = FactoryGirl.create(:bike, year: 1969, frame_model: 'Hobo')
      allow(public_image).to receive(:imageable_type).and_return('Bike')
      allow(public_image).to receive(:imageable).and_return(bike)
      public_image.default_name
      expect(public_image.name).to eq("#{bike.title_string} #{bike.frame_colors.to_sentence}")
    end
  end

  describe 'lottapixel' do
    it "doesn't break" do
      lottapixel = File.open(File.join(Rails.root, 'spec', 'fixtures', 'hugeimg.png'))
      public_image = FactoryGirl.build(:public_image, image: lottapixel)
      public_image.save
      expect(public_image.id).to be_nil
      expect(public_image.errors.full_messages.to_s.match('dimensions too large')).to be_truthy
    end
  end

  describe 'update_bike_listing_order' do
    context 'non-bike' do
      let(:public_image) { PublicImage.new(imageable_type: 'Blog', imageable_id: 12) }
      it 'does not enqueue after_bike_save_worker' do
        expect do
          public_image.update_bike_listing_order
        end.to change(AfterBikeSaveWorker.jobs, :size).by(0)
      end
    end
    context 'bike' do
      let(:public_image) { PublicImage.new(imageable_type: 'Bike', imageable_id: 12) }
      it 'enqueues after_bike_save_worker' do
        expect do
          public_image.update_bike_listing_order
        end.to change(AfterBikeSaveWorker.jobs, :size).by(1)
      end
    end
    it 'has an after_save callback' do
      expect(PublicImage._save_callbacks.select { |cb| cb.kind.eql?(:after) }
        .map(&:raw_filter).include?(:update_bike_listing_order)).to eq(true)
    end
  end
end
