require "rails_helper"

RSpec.describe "bikes routing", type: :routing do
  describe "scanned" do
    context "scanned_id in route" do
      it "directs to scanned" do
        expect(get: "bikes/scanned/b2100061").to route_to(
          controller: "bikes",
          action: "scanned",
          scanned_id: "b2100061"
        )
      end
    end
    context "id" do
      it "directs to scanned" do
        expect(get: "bikes/12/scanned").to route_to(
          controller: "bikes",
          action: "scanned",
          id: "12"
        )
      end
    end
    context "card_id" do
      it "directs to scanned" do
        expect(get: "bikes/scanned?card_id=xxxxxx").to route_to(
          controller: "bikes",
          action: "scanned",
          card_id: "xxxxxx"
        )
      end
    end
  end

  describe "edit" do
    it "directs to edit" do
      expect(get: "bikes/111/edit").to route_to(
        controller: "bikes/edits",
        action: "show",
        id: "111"
      )
    end
    context "edit_template parameter" do
      it "directs to edit" do
        expect(get: "bikes/111/edit/photos").to route_to(
          controller: "bikes/edits",
          action: "show",
          id: "111",
          edit_template: "photos"
        )
      end
      it "includes query string" do
        expect(get: "bikes/111/edit/photos?party=true").to route_to(
          controller: "bikes/edits",
          action: "show",
          id: "111",
          edit_template: "photos",
          party: "true"
        )
      end
    end
    context "edit_template parameter" do
      it "directs to edit" do
        expect(get: "bikes/111/edit?edit_template=photos").to route_to(
          controller: "bikes/edits",
          action: "show",
          id: "111",
          edit_template: "photos"
        )
      end
    end
  end
end
