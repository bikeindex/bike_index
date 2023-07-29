class CarrierWaveStoreWorker < ::CarrierWave::Workers::StoreAsset
  sidekiq_options queue: "carrierwave", backtrace: true, retry: 2, dead: false
end
