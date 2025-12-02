# frozen_string_literal: true

module PageBlock::HomepageTop
  class Component < ApplicationComponent
    def initialize(recoveries_value:, organization_count:, recovery_displays:)
      @recoveries_value = recoveries_value
      @organization_count = organization_count
      @recovery_displays = recovery_displays
    end

    private

    def bike_tile_images
      [
        'redesign_2025/bike_tiles/bike-entry_0000.png',
        'redesign_2025/bike_tiles/bike-entry_0001.png',
        'redesign_2025/bike_tiles/bike-entry_0002.png',
        'redesign_2025/bike_tiles/bike-entry_0003.png',
        'redesign_2025/bike_tiles/bike-entry_0004.png',
        'redesign_2025/bike_tiles/bike-entry_0005.png',
        'redesign_2025/bike_tiles/bike-entry_0006.png',
        'redesign_2025/bike_tiles/bike-entry_0007.png',
        'redesign_2025/bike_tiles/bike-entry_0008.png',
        'redesign_2025/bike_tiles/bike-entry_0009.png',
        'redesign_2025/bike_tiles/bike-entry_0010.png',
        'redesign_2025/bike_tiles/bike-entry_0011.png',
        'redesign_2025/bike_tiles/bike-entry_0012.png',
        'redesign_2025/bike_tiles/bike-entry_0013.png',
        'redesign_2025/bike_tiles/bike-entry_0014.png',
        'redesign_2025/bike_tiles/bike-entry_0015.png',
        'redesign_2025/bike_tiles/bike-entry_0016.png'
      ].map { image_url(it) }
    end
  end
end
