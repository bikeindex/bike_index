require "rails_helper"

RSpec.describe ApplicationDecorator do
  describe "dl_list_item" do
    it "returns a dt and dd from what's passed attribute" do
      bike = Bike.new
      dl_list = ApplicationDecorator.new(bike).dl_list_item("description", "title")
      expect(dl_list).to eq("<dt>title</dt><dd>description</dd>")
    end
  end

  describe "dl_from_attribute" do
    it "returns nil if the attribute isn't present" do
      bike = Bike.new
      decorator = ApplicationDecorator.new(bike)
      allow(decorator).to receive(:if_present).and_return(nil)
      expect(decorator.dl_from_attribute("serial_number")).to be_nil
    end
    it "returns a dt and dd from the attribute" do
      bike = Bike.new
      decorator = ApplicationDecorator.new(bike)
      allow(decorator).to receive(:if_present).and_return("cereal")
      expect(decorator).to receive(:dl_list_item).with("cereal", "Serial Number")
      decorator.dl_from_attribute("serial_number")
    end
  end

  describe "if_present" do
    it "returns the attribute if it's present" do
      lock = Lock.new
      allow(lock).to receive(:manufacturer_other).and_return("thingsy")
      expect(ApplicationDecorator.new(lock).if_present("manufacturer_other")).to eq("thingsy")
    end
  end

  describe "ass_name" do
    it "grabs the association name" do
      wheel_size = FactoryBot.create(:wheel_size, name: "foobar", iso_bsd: 559)
      bike = FactoryBot.create(:bike, front_wheel_size: wheel_size, name: "some bike")
      expect(ApplicationDecorator.new(bike).ass_name("front_wheel_size")).to eq("foobar")
    end
  end
end
