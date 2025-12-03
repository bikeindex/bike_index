# frozen_string_literal: true

module PageBlock::HomepageTop
  class Component < ApplicationComponent
    def initialize(recoveries_value:, organization_count:, recovery_displays:)
      @recoveries_value = recoveries_value
      @organization_count = organization_count
      @recovery_displays = recovery_displays.select { it.photo_url.present? }
    end

    private

    def bike_tile_images
      (0..16).map { it.to_s.rjust(2, "0") }
        .map { image_url("redesign_2025/bike_tiles/bike-entry_00#{it}.png") }
    end

    def recoveries_value
      (@recoveries_value / 1_000_000)
    end

    def recovery_steps
      [
        {
          stepNumber: "STEP 1",
          title: "REGISTER YOUR BIKE",
          text: "It's simple. Submit your name, bike manufacturer, serial number, and component information to enter your bike into the most widely used bike registry on the planet.",
          background: image_url("redesign_2025/step1.gif"),
          rotation: 0
        },
        {
          stepNumber: "STEP 2",
          title: "ALERT THE COMMUNITY",
          text: "If your bike goes missing, mark it as lost or stolen to notify the entire Bike Index community and its partners.",
          background: image_url("redesign_2025/step2.gif"),
          rotation: 90
        },
        {
          stepNumber: "STEP 3",
          title: "THE COMMUNITY RESPONDS",
          text: "A user or partner encounters your bike, uses Bike Index to identify it, and contacts you.",
          background: image_url("redesign_2025/step3.gif"),
          rotation: 180
        },
        {
          stepNumber: "STEP 4",
          title: "YOU GET YOUR BIKE BACK",
          text: "With the help of the Bike Index community and its partners, you have the information necessary to recover your lost or stolen bike at no cost to you. It's what we do.",
          background: image_url("redesign_2025/step4.gif"),
          rotation: 270
        }
      ]
    end
  end
end
