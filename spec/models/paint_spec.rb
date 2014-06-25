require 'spec_helper'

describe Paint do



  it { should validate_presence_of :name }
  it { should validate_uniqueness_of :name }
  it { should belong_to :color }
  it { should belong_to :secondary_color }
  it { should belong_to :tertiary_color }
  it { should belong_to :manufacturer }
  it { should have_many :bikes }

  describe "lowercase name" do
    it "should make the name lowercase on save" do
      pd = Paint.create(name: "Hazel or Something")
      pd.name.should eq("hazel or something")
    end
  end


  describe :fuzzy_name_find do
    it "should find users by email address when the case doesn't match" do
      paint = FactoryGirl.create(:paint, name: "Poopy PAiNTERS")
      Paint.fuzzy_name_find('poopy painters').should == paint
    end
  end

  describe :assign_colors do
    before(:each) do
      bi_colors = ["Black", "Blue", "Brown", "Green", "Orange", "Pink", "Purple", "Raw metal", "Red", "Silver or Gray", "Stickers tape or other cover-up", "Teal", "White", "Yellow or Gold"]
      bi_colors.each do |col|
        FactoryGirl.create(:color, name: col)
      end
    end
    it "should associate paint with reasonable colors" do
      paint = FactoryGirl.create(:paint, name: "burgandy/ivory with black stripes")
      expect(paint.color.name.downcase).to eq("red")
      expect(paint.secondary_color.name.downcase).to eq("white")
      expect(paint.tertiary_color.name.downcase).to eq("black")
    end
    it "should associate only as many colors as it finds" do
      paint = FactoryGirl.create(:paint, name: "wood with leaf details")
      expect(paint.color.name.downcase).to eq("brown")
      expect(paint.secondary_color).to be_nil
      expect(paint.tertiary_color).to be_nil
    end
  end
end
