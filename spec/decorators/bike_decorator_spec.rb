require "rails_helper"

RSpec.describe BikeDecorator do
  describe "show_other_bikes" do
    it "links to bikes if the user is the current owner and wants to share" do
      bike = Bike.new
      user = User.new
      allow(bike).to receive(:user).and_return(user)
      allow(user).to receive(:show_bikes).and_return(true)
      allow(user).to receive(:username).and_return("i")
      decorator = BikeDecorator.new(bike)
      allow(bike).to receive(:user?).and_return(true)
      expect(decorator.show_other_bikes.match("href='/users/i")).to be_present
    end
  end

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

  describe "#creation_organization_name" do
    context "given an associated creation_organization" do
      it "returns the organization's name" do
        org = FactoryBot.create(:organization, name: "Creation Organization")
        bike = FactoryBot.create(:bike, creation_organization: org).decorate
        name = bike.creation_organization_name
        expect(name).to eq(org.name)
      end
    end

    context "given no associated creation_organization" do
      it "returns nil" do
        bike = FactoryBot.create(:bike, creation_organization: nil).decorate
        name = bike.creation_organization_name
        expect(name).to be_nil
      end
    end
  end

  describe "tire_width" do
    it "returns wide if false" do
      bike = Bike.new
      allow(bike).to receive(:front_tire_narrow).and_return(nil)
      decorator = BikeDecorator.new(bike).tire_width("front")
      expect(decorator).to eq("wide")
    end
    it "returns narrow if narrow" do
      bike = Bike.new
      allow(bike).to receive(:rear_tire_narrow).and_return(true)
      decorator = BikeDecorator.new(bike).tire_width("rear")
      expect(decorator).to eq("narrow")
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

  describe "list_image" do
    it "returns the link with  thumb path if nothing is passed" do
      bike = Bike.new
      allow(bike).to receive(:id).and_return(69)
      decorator = BikeDecorator.new(bike)
      allow(decorator).to receive(:thumb_image).and_return("imagey")
      expect(decorator.list_image).not_to be_nil
    end
    it "returns the images thumb path" do
      bike = Bike.new
      allow(bike).to receive(:id).and_return(69)
      allow(bike).to receive(:thumb_path).and_return("something")
      decorator = BikeDecorator.new(bike)
      allow(decorator).to receive(:thumb_image).and_return("imagey")
      expect(decorator.list_image).not_to be_nil
    end
  end
end
