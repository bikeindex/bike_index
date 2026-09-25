require "rails_helper"

RSpec.describe Integrations::Shopify::OrderParser do
  let(:bike_line_item) do
    {"title" => "Trek Domane AL 2", "vendor" => "Trek", "quantity" => 1, "properties" => []}
  end
  let(:helmet_line_item) do
    {"title" => "Bontrager Starvos Helmet", "vendor" => "Bontrager", "quantity" => 1, "properties" => []}
  end
  let(:order) do
    {"email" => "rider@example.com", "note" => nil, "note_attributes" => [],
     "line_items" => [bike_line_item]}
  end

  describe "registerable?" do
    it "is truthy for a live sale with a customer" do
      expect(described_class.registerable?(order)).to be_truthy
    end

    it "takes the email off the customer when the order has none" do
      order_with_customer = order.merge("email" => nil, "customer" => {"email" => "rider@example.com"})
      expect(described_class.owner_email(order_with_customer)).to eq "rider@example.com"
      expect(described_class.registerable?(order_with_customer)).to be_truthy
    end

    # Nothing can be registered without an address to send the claim email to
    it "is falsey without an email, and for a test or cancelled sale" do
      expect(described_class.registerable?(order.merge("email" => nil))).to be_falsey
      expect(described_class.registerable?(order.merge("test" => true))).to be_falsey
      expect(described_class.registerable?(order.merge("cancelled_at" => "2026-09-01T00:00:00-04:00"))).to be_falsey
      expect(described_class.registerable?(nil)).to be_falsey
    end
  end

  describe "registrations" do
    it "is empty when nothing in the sale carries a serial" do
      expect(described_class.registrations(order)).to eq([])
      expect(described_class.registrations(nil)).to eq([])
    end

    context "serial on a line item property" do
      let(:bike_line_item) do
        {"title" => "Trek Domane AL 2", "vendor" => "Trek", "quantity" => 1,
         "properties" => [{"name" => "Serial", "value" => "WTU123K0912"}]}
      end
      let(:order) do
        {"email" => "rider@example.com", "note" => nil, "note_attributes" => [],
         "line_items" => [bike_line_item, helmet_line_item]}
      end

      it "registers that line item's product, and leaves the helmet alone" do
        registrations = described_class.registrations(order)
        expect(registrations.count).to eq 1
        expect(registrations.first).to have_attributes(serial: "WTU123K0912",
          manufacturer: "Trek", frame_model: "Trek Domane AL 2")
      end
    end

    context "serial in the order note" do
      let(:order) do
        {"email" => "rider@example.com", "note" => "Serial: WTU123K0912",
         "note_attributes" => [], "line_items" => [bike_line_item]}
      end

      it "resolves to the only line item" do
        expect(described_class.registrations(order).first)
          .to have_attributes(serial: "WTU123K0912", manufacturer: "Trek")
      end

      # A note names no line item, so a multi-item sale can't say which product it meant
      context "and more than one line item" do
        let(:order) { super().merge("line_items" => [bike_line_item, helmet_line_item]) }

        it "registers the serial with an unknown manufacturer" do
          expect(described_class.registrations(order).first)
            .to have_attributes(serial: "WTU123K0912", manufacturer: "Unknown", frame_model: nil)
        end
      end
    end

    context "serial in a note attribute" do
      let(:order) do
        {"email" => "rider@example.com", "note" => nil,
         "note_attributes" => [{"name" => "S/N", "value" => "FR8842"}],
         "line_items" => [bike_line_item]}
      end

      it "registers it" do
        expect(described_class.registrations(order).map(&:serial)).to eq(["FR8842"])
      end
    end

    context "the same serial on the line item and in the note" do
      let(:bike_line_item) do
        {"title" => "Trek Domane AL 2", "vendor" => "Trek", "quantity" => 1,
         "properties" => [{"name" => "Serial", "value" => "WTU123K0912"}]}
      end
      let(:order) do
        {"email" => "rider@example.com", "note" => "Serial: WTU123K0912",
         "note_attributes" => [], "line_items" => [bike_line_item]}
      end

      # The line item match wins - it's the one that knows which product was sold
      it "registers it once, with the product" do
        registrations = described_class.registrations(order)
        expect(registrations.count).to eq 1
        expect(registrations.first).to have_attributes(serial: "WTU123K0912", manufacturer: "Trek")
      end
    end

    context "two bikes on one sale" do
      let(:second_bike) do
        {"title" => "Trek FX 1", "vendor" => "Trek", "quantity" => 1,
         "properties" => [{"name" => "Serial", "value" => "BBB222"}]}
      end
      let(:bike_line_item) do
        {"title" => "Trek Domane AL 2", "vendor" => "Trek", "quantity" => 1,
         "properties" => [{"name" => "Serial", "value" => "AAA111"}]}
      end
      let(:order) do
        {"email" => "rider@example.com", "note" => nil, "note_attributes" => [],
         "line_items" => [bike_line_item, second_bike]}
      end

      it "registers each against its own product" do
        registrations = described_class.registrations(order)
        expect(registrations.map(&:serial)).to eq(%w[AAA111 BBB222])
        expect(registrations.map(&:frame_model)).to eq(["Trek Domane AL 2", "Trek FX 1"])
      end
    end
  end
end
