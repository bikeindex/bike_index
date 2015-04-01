class CarrierWaveStoreWorker < ::CarrierWave::Workers::StoreAsset
  sidekiq_options queue: 'carrierwave', backtrace: true, :retry => 3, :dead => false
    
end