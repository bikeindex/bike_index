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
      public_image.name.should eq("1969 #{bike.manufacturer.name} Hobo #{bike.type} #{bike.frame_colors.to_sentence}")
    end
  end

end
