# frozen_string_literal: true

module Backfills
  class WheelSizesJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    WHEEL_SIZES = [
      {iso_bsd: 53, name: "7.7 x 2.8in", priority: "rare", description: "7.7 x 2.8in (196 x 71) PU wheel, Vanpowers VanSwift mobility scooter (Rare)"},
      {iso_bsd: 102, name: "7 x 1.5in", priority: "rare", description: "7 x 1.5in (178 x 38) solid wheel, NIU KQi Youth kids' e-scooter rear (Rare)"},
      {iso_bsd: 115, name: "7.5 x 1.5in", priority: "rare", description: "7.5 x 1.5in (191 x 38) solid wheel, NIU KQi Youth kids' e-scooter front (Rare)"},
      {iso_bsd: 155, name: "9.5in", priority: "uncommon", description: "9.5in (9.5 x 2.5-6.1) NIU KQi3, KQi 100 and KQi Air e-scooters (Uncommon)"},
      {iso_bsd: 178, name: "10.5in", priority: "uncommon", description: "10.5in (10.5 x 2.5-7) NIU KQi 300 e-scooters (Uncommon)"},
      {iso_bsd: 356, name: "14in moto", priority: "uncommon", description: "14in motorcycle rim (60/100-14, 2.50-14) Talaria, Sur-Ron and Xion CyberX e-motos (Uncommon)"},
      {iso_bsd: 533, name: "21in moto", priority: "uncommon", description: "21in motorcycle rim (70/100-21, 80/100-21) Stark Varg front, Xion pedicabs' rear (Uncommon)"}
    ].freeze

    def perform
      WHEEL_SIZES.each do |attributes|
        WheelSize.find_or_initialize_by(iso_bsd: attributes[:iso_bsd]).update!(attributes)
      end
    end
  end
end
