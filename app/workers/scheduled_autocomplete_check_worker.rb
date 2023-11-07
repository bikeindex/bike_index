# See PR#2483 - frequency can definitely be dropped a month or 2 after 2023-11
class ScheduledAutocompleteCheckWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    4.minutes
  end

  def perform
    if Autocomplete::Loader.frame_mnfg_count < Manufacturer.frame_makers.count
      AutocompleteLoaderWorker.perform_async
      raise "Missing Manufacturers!"
    end
  end
end
