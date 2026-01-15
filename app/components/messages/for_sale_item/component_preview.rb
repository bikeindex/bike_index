# frozen_string_literal: true

module Messages::ForSaleItem
  class ComponentPreview < ApplicationComponentPreview
    # @display legacy_stylesheet true
    def default
      render(Messages::ForSaleItem::Component.new(current_user: lookbook_user,
        vehicle: test_vehicle))
    end

    # @display legacy_stylesheet true
    def deleted_vehicle
      marketplace_listing = MarketplaceListing.find_by_id(1)

      render(Messages::ForSaleItem::Component.new(current_user: lookbook_user,
        vehicle: nil, vehicle_id: 2796501, marketplace_listing:))
    end

    private

    def test_vehicle
      Bike.new(
        id: 35,
        serial_number: "XXX999",
        mnfg_name: "Humble Frameworks",
        year: "2015",
        primary_frame_color_id: Color.where(name: "Purple").first_or_create,
        frame_model: "self titled",
        frame_material: :steel,
        cycle_type: :bike,
        is_for_sale: true,
        thumb_path: "https://files.bikeindex.org/uploads/Pu/395980/small_D3C6B1AF-F1FC-4BAA-BD39-9C107871FCAE.jpeg"
      )
    end
  end
end
