require "rails_helper"

RSpec.describe BikeDecorator do
  describe "title" do
    it "returns the major bike attribs formatted" do
      bike = Bike.new
      allow(bike).to receive(:year).and_return("1999")
      allow(bike).to receive(:frame_model).and_return("model")
      allow(bike).to receive(:mnfg_name).and_return("foo")
      decorator = BikeDecorator.new(bike)
      expect(decorator.title).to eq("<span>1999 model by </span><strong>foo</strong>")
    end
  end

  describe "list_link_url" do
    it "returns the bike edit path if edit" do
      bike = Bike.new
      allow(bike).to receive(:id).and_return(69)
      decorator = BikeDecorator.new(bike).list_link_url("edit")
      expect(decorator).to eq("/bikes/69/edit")
    end

    it "returns the normal path if passed" do
      bike = Bike.new
      allow(bike).to receive(:id).and_return(69)
      decorator = BikeDecorator.new(bike).list_link_url
      expect(decorator).to eq("/bikes/69")
    end
  end

  describe "thumb_image" do
    context "bike photo exists" do
      it "returns the thumb path if one exists" do
        bike = Bike.new
        allow(bike).to receive(:thumb_path).and_return("pathy")
        decorator = BikeDecorator.new(bike)
        allow(decorator).to receive(:title_string).and_return("Title")
        expect(decorator.thumb_image).to match(%r{img alt="Title"})
        expect(decorator.thumb_image).to match(%r{src=".+images/pathy"})
      end
    end
    context "bike photo does not exist" do
      it "returns the bike placeholder path" do
        bike = Bike.new
        decorator = BikeDecorator.new(bike)
        allow(decorator).to receive(:title_string).and_return("Title")
        html = decorator.thumb_image
        expect(html).to match("alt=\"Title\"")
        expect(html).to match('title=\"No image\"')
        expect(html).to match(/revised.bike_photo_placeholder.*\.svg/)
      end
    end
  end
end
