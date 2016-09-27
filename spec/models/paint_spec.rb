require 'spec_helper'

describe Paint do
  it_behaves_like 'friendly_name_findable'
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_uniqueness_of :name }
    it { is_expected.to belong_to :color }
    it { is_expected.to belong_to :secondary_color }
    it { is_expected.to belong_to :tertiary_color }
    it { is_expected.to belong_to :manufacturer }
    it { is_expected.to have_many :bikes }
  end

  describe 'lowercase name' do
    it 'makes the name lowercase on save' do
      pd = Paint.create(name: 'Hazel or Something')
      expect(pd.name).to eq('hazel or something')
    end
  end

  describe 'friendly_find' do
    it "finds users by email address when the case doesn't match" do
      paint = FactoryGirl.create(:paint, name: 'Poopy PAiNTERS')
      expect(Paint.friendly_find('poopy painters')).to eq(paint)
    end
  end

  describe 'assign_colors' do
    before(:each) do
      bi_colors = ['Black', 'Blue', 'Brown', 'Green', 'Orange', 'Pink', 'Purple', 'Red', 'Silver or Gray', 'Stickers tape or other cover-up', 'Teal', 'White', 'Yellow or Gold']
      bi_colors.each do |col|
        FactoryGirl.create(:color, name: col)
      end
    end
    it 'associates paint with reasonable colors' do
      paint = Paint.new(name: 'burgandy/ivory with black stripes')
      paint.associate_colors
      expect(paint.color.name.downcase).to eq('red')
      expect(paint.secondary_color.name.downcase).to eq('white')
      expect(paint.tertiary_color.name.downcase).to eq('black')
    end

    it 'associates only as many colors as it finds' do
      paint = Paint.new(name: 'wood with leaf details')
      paint.associate_colors
      expect(paint.color.name.downcase).to eq('brown')
      expect(paint.secondary_color).to be_nil
      expect(paint.tertiary_color).to be_nil
    end

    it 'has before_create_callback_method' do
      expect(Paint._create_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:associate_colors)).to eq(true)
    end
  end
end
