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
    expect(Paint._create_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:associate_colors)).to eq(true)
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
