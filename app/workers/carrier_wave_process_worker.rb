class CarrierWaveProcessWorker < ::CarrierWave::Workers::ProcessAsset
  sidekiq_options queue: "med_priority", backtrace: true, retry: 1
end
