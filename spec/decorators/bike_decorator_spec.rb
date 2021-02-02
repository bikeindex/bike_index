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

  describe "title_html" do
    let(:bike) { Bike.new }
    let(:decorator) { BikeDecorator.new(bike) }
    it "returns expected thing" do
      expect(decorator.title_html).to eq("<span><strong></strong></span>")
    end
    context "html frame_model" do
      let(:bike) { Bike.new(frame_model: "escape tags?</p>") }
      it "escapes the HTML" do
        expect(decorator.title_html).to eq("<span><strong></strong> escape tags?&amp;lt;&amp;#x2F;p&amp;gt;</span>")
      end
    end
  end

  describe "status_html" do
    let(:decorator) { BikeDecorator.new(Bike.new(status: status)) }
    let(:status) { "status_with_owner" }
    it "responds with nil" do
      expect(decorator.status_html).to be_blank
    end
    context "stolen" do
      let(:status) { "status_stolen" }
      let(:target) { "<strong class=\"stolen-color uppercase bike-status-html\">stolen</strong>" }
      it "responds with strong" do
        expect(decorator.status_html).to eq target
      end
    end
    context "impounded" do
      let(:status) { "status_impounded" }
      let(:target) { "<strong class=\"impounded-color uppercase bike-status-html\">impounded</strong>" }
      it "responds with strong" do
        expect(decorator.status_html).to eq target
      end
    end
  end
end
