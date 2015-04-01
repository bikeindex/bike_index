class CarrierWaveProcessWorker < ::CarrierWave::Workers::ProcessAsset
  sidekiq_options queue: 'carrierwave', backtrace: true, :retry => 3, :dead => false
    
end