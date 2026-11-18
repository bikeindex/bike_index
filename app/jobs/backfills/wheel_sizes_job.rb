# frozen_string_literal: true

module Backfills
  class WheelSizesJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    WHEEL_SIZES = [
      {iso_bsd: 155, name: "9.5in", priority: "uncommon", description: "9.5in (9.5 x 2.5-6.1) NIU KQi3, KQi 100 and KQi Air e-scooters (Uncommon)"},
      {iso_bsd: 178, name: "10.5in", priority: "uncommon", description: "10.5in (10.5 x 2.5-7) NIU KQi 300 e-scooters (Uncommon)"},
      {iso_bsd: 330, name: "13in moto", priority: "rare", description: "13in motorcycle/automotive rim (130/60-13, 145/80R13) Urban Arrow Tender (Rare)"},
      {iso_bsd: 356, name: "14in moto", priority: "uncommon", description: "14in motorcycle rim (60/100-14, 90/90-14, 80/90-14) Talaria, Sur-Ron and Xion CyberX e-motos (Uncommon)"},
      {iso_bsd: 501, name: "22 x 1 3/8", priority: "rare", description: "22 x 1 3/8 (37-501) Japanese bicycles, Miyata Spiky (Rare)"},
      {iso_bsd: 508, name: "20in moto", priority: "rare", description: "20in motorcycle rim (70/100-20) NIU XQi3 rear (Rare)"},
      {iso_bsd: 533, name: "21in moto", priority: "rare", description: "21in motorcycle rim (70/100-21, 80/100-21, 90/100-21) Stark, Talaria, NIU, Bakcou and Goat Power e-motos (Rare)"}
    ].freeze

    def perform
      WHEEL_SIZES.each do |attributes|
        WheelSize.find_or_initialize_by(iso_bsd: attributes[:iso_bsd]).update!(attributes)
      end
    end
  end
end
