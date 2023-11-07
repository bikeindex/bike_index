# Since re-writing soulheart internally (PR#2423), the autocomplete list has been empty
# TWICE
# This means that bike registration is silently broken, because you can't register without a manufacturer
# I _think_ it was just because admin manufacturers had a bug, but...
# run a scheduled job, fix it if it's broken and throw an error so we know
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
