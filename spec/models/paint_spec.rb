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
      paint = Paint.new(name: "burgandy/ivory with black stripes")
      paint.associate_colors
      expect(paint.color.name.downcase).to eq("red")
      expect(paint.secondary_color.name.downcase).to eq("white")
      expect(paint.tertiary_color.name.downcase).to eq("black")
    end

    it "should associate only as many colors as it finds" do
      paint = Paint.new(name: "wood with leaf details")
      paint.associate_colors
      pp paint
      expect(paint.color.name.downcase).to eq("brown")
      expect(paint.secondary_color).to be_nil
      expect(paint.tertiary_color).to be_nil
    end

    it "should have before_create_callback_method" do
      Paint._create_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:associate_colors).should == true
    end
  end
end
