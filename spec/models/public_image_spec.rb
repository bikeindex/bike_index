require 'spec_helper'

describe PublicImage do
  describe :validations do
    it { should belong_to :imageable }
  end
  
  describe :default_name do 
    it "sets a default name from filename if not bike" do 
      public_image = PublicImage.new
      public_image.stub(:imageable_type).and_return("Nope")
      public_image.stub(:name).and_return("Boop")
      public_image.default_name
      public_image.name.should eq('Boop')
    end

    it "returns the name of the manufacturer if it isn't other" do
      public_image = PublicImage.new
      bike = FactoryGirl.create(:bike, year: 1969, frame_model: "Hobo")
      public_image.stub(:imageable_type).and_return("Bike")
      public_image.stub(:imageable).and_return(bike)
      public_image.default_name
      public_image.name.should eq("#{bike.title_string} #{bike.frame_colors.to_sentence}")
    end
  end

  describe 'lottapixel' do 
    it "doesn't break" do 
      lottapixel = File.open(File.join(Rails.root, 'spec', 'fixtures', 'lottapixel.jpg'))
      public_image = FactoryGirl.build(:public_image, image: lottapixel)
      public_image.save
      public_image.id.should be_nil
      public_image.errors.full_messages.to_s.match('dimensions too large').should be_true
    end
  end

end
