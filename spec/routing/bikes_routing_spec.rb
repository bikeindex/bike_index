require "spec_helper"

describe "bikes routing" do
  context "scanned" do
    describe "scanned_id in route" do
      it "directs to scanned" do
        expect(get: "bikes/scanned/b2100061").to route_to(
          controller: "bikes",
          action: "scanned",
          scanned_id: "b2100061"
        )
      end
    end
    describe "id" do
      it "directs to scanned" do
        expect(get: "bikes/12/scanned").to route_to(
          controller: "bikes",
          action: "scanned",
          id: "12"
        )
      end
    end
    describe "card_id" do
      it "directs to scanned" do
        expect(get: "bikes/scanned?card_id=xxxxxx").to route_to(
          controller: "bikes",
          action: "scanned",
          card_id: "xxxxxx"
        )
      end
    end
  end
end