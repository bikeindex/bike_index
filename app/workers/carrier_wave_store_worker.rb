class CarrierWaveStoreWorker < ::CarrierWave::Workers::StoreAsset
  sidekiq_options queue: "med_priority", backtrace: true, retry: 2, dead: false
end
