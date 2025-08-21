# == Schema Information
#
# Table name: paints
#
#  id                 :integer          not null, primary key
#  bikes_count        :integer          default(0), not null
#  name               :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  color_id           :integer
#  manufacturer_id    :integer
#  secondary_color_id :integer
#  tertiary_color_id  :integer
#
require "rails_helper"

RSpec.describe Paint, type: :model do
  it_behaves_like "friendly_name_findable"
  describe "lowercase name" do
    it "makes the name lowercase on save" do
      pd = Paint.create(name: "Hazel or Something")
      expect(pd.name).to eq("hazel or something")
    end
  end

  describe "friendly_find" do
    it "finds color when the case doesn't match" do
      paint = FactoryBot.create(:paint, name: "Poopy PAiNTERS")
      expect(Paint.friendly_find("poopy painters")).to eq(paint)
    end
  end

  it "has before_create_callback_method" do
    expect(Paint._create_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:filter).include?(:associate_colors)).to eq(true)
  end

  describe "paint_name_parser" do
    it "returns black for black" do
      expect(Paint.paint_name_parser("BLACK")).to eq "black"
      expect(Paint.paint_name_parser("BLCK")).to eq "black"
      expect(Paint.paint_name_parser("BLK")).to eq "black"
    end
    it "returns whtie for white" do
      expect(Paint.paint_name_parser("WHiTe")).to eq "white"
      expect(Paint.paint_name_parser("whit")).to eq "white"
      expect(Paint.paint_name_parser("wht")).to eq "white"
    end
    it "returns for shortened" do
      expect(Paint.paint_name_parser("purpl")).to eq "purple"
      expect(Paint.paint_name_parser("gren")).to eq "green"
      expect(Paint.paint_name_parser("pnk")).to eq "pink"
      expect(Paint.paint_name_parser("blu")).to eq "blue"
      expect(Paint.paint_name_parser("gry")).to eq "silver"
      expect(Paint.paint_name_parser("slvr")).to eq "silver"
    end
    it "returns without ish" do
      expect(Paint.paint_name_parser("reddish")).to eq "red"
      expect(Paint.paint_name_parser("redish")).to eq "red"
      expect(Paint.paint_name_parser("bluish")).to eq "blue"
      expect(Paint.paint_name_parser("blue-ish")).to eq "blue"
      expect(Paint.paint_name_parser("pinkish")).to eq "pink"
      expect(Paint.paint_name_parser("grayish")).to eq "silver"
      expect(Paint.paint_name_parser("purpleish")).to eq "purple"
    end
  end

  describe "assign_colors" do
    before { Color::ALL_NAMES.each { |c| FactoryBot.create(:color, name: c) } }

    it "associates paint with reasonable colors" do
      paint = Paint.new(name: "burgandy/ivory with black stripes")
      paint.associate_colors
      expect(paint.color.name.downcase).to eq("red")
      expect(paint.secondary_color.name.downcase).to eq("white")
      expect(paint.tertiary_color.name.downcase).to eq("black")
    end

    it "associates mint" do
      expect(Color.friendly_find("green")).to be_present
      paint = Paint.new(name: "mint")
      paint.associate_colors
      expect(paint.color.name.downcase).to eq("green")
      expect(paint.secondary_color_id).to be_blank
      expect(paint.tertiary_color_id).to be_blank
    end

    it "associates only as many colors as it finds" do
      paint = Paint.new(name: "wood with leaf details")
      paint.associate_colors
      expect(paint.color.name.downcase).to eq("brown")
      expect(paint.secondary_color).to be_nil
      expect(paint.tertiary_color).to be_nil
    end
  end
end
