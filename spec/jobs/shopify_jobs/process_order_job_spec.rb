require "rails_helper"

RSpec.describe ShopifyJobs::ProcessOrderJob, type: :job do
  let(:organization) { FactoryBot.create(:organization, :with_auto_user, kind: "bike_shop") }
  let(:shopify_integration) { FactoryBot.create(:shopify_integration, :active, organization:) }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Trek") }
  let!(:color) { FactoryBot.create(:color, name: "Black") }
  let(:line_item) do
    {"title" => "Trek Domane AL 2", "vendor" => "Trek", "quantity" => 1,
     "properties" => [{"name" => "Serial", "value" => "WTU123K0912"}]}
  end
  let(:order) do
    {"id" => 5551212, "email" => "rider@example.com", "note" => nil, "note_attributes" => [],
     "customer" => {"first_name" => "Sam", "last_name" => "Rider"}, "line_items" => [line_item]}
  end

  it "registers the bike to the buyer, credited to the shop's POS" do
    expect { described_class.new.perform(shopify_integration.id, order) }
      .to change(Bike, :count).by(1)

    bike = Bike.last
    expect(bike).to have_attributes(serial_number: "WTU123K0912", frame_model: "Trek Domane AL 2",
      manufacturer_id: manufacturer.id, owner_email: "rider@example.com",
      creation_organization_id: organization.id)
    expect(bike.current_ownership).to have_attributes(pos_kind: "shopify_pos",
      origin: "shopify_webhook", claimed: false, organization_id: organization.id)
    expect(bike.current_ownership.creation_kind).to eq :shopify_pos
    expect(shopify_integration.reload.last_order_at).to be_present
  end

  # orders/updated redelivers the whole sale every time the shop edits it
  it "does not register the same sale twice" do
    described_class.new.perform(shopify_integration.id, order)
    expect { described_class.new.perform(shopify_integration.id, order) }
      .to_not change(Bike, :count)
  end

  context "no serial anywhere in the sale" do
    let(:line_item) { super().merge("properties" => []) }

    it "registers nothing" do
      expect { described_class.new.perform(shopify_integration.id, order) }
        .to_not change(Bike, :count)
      expect(shopify_integration.reload.last_order_at).to be_nil
    end
  end

  context "a sale with a bike and an accessory" do
    let(:helmet) do
      {"title" => "Bontrager Starvos Helmet", "vendor" => "Bontrager", "quantity" => 1, "properties" => []}
    end
    let(:order) { super().merge("line_items" => [line_item, helmet]) }

    it "registers only the line item carrying a serial" do
      expect { described_class.new.perform(shopify_integration.id, order) }
        .to change(Bike, :count).by(1)
      expect(Bike.last.frame_model).to eq "Trek Domane AL 2"
    end
  end

  context "serial in the order note on a single-item sale" do
    let(:line_item) { super().merge("properties" => []) }
    let(:order) { super().merge("note" => "S/N: FR8842") }

    it "registers it against that product" do
      expect { described_class.new.perform(shopify_integration.id, order) }
        .to change(Bike, :count).by(1)
      expect(Bike.last).to have_attributes(serial_number: "FR8842", manufacturer_id: manufacturer.id)
    end
  end

  context "a vendor with no matching manufacturer" do
    let!(:manufacturer) { Manufacturer.other }
    let(:line_item) { super().merge("vendor" => "Some Local Framebuilder") }

    it "registers under Other, keeping the vendor name" do
      expect { described_class.new.perform(shopify_integration.id, order) }
        .to change(Bike, :count).by(1)
      expect(Bike.last).to have_attributes(manufacturer_id: Manufacturer.other.id,
        manufacturer_other: "Some Local Framebuilder", serial_number: "WTU123K0912")
    end
  end

  context "the integration is gone" do
    it "does nothing" do
      shopify_integration.destroy
      expect { described_class.new.perform(shopify_integration.id, order) }
        .to_not change(Bike, :count)
    end
  end

  context "the sale has no customer email" do
    let(:order) { super().merge("email" => nil, "customer" => {}) }

    it "registers nothing" do
      expect { described_class.new.perform(shopify_integration.id, order) }
        .to_not change(Bike, :count)
    end
  end
end
