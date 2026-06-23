# See PR#2483 - frequency can definitely be dropped a month or 2 after 2023-11
class ScheduledAutocompleteCheckJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    4.minutes
  end

  def perform
    if too_few_autocomplete_manufacturers?
      AutocompleteLoaderJob.perform_async
      raise "Missing Manufacturers!"
    end
  end

  def too_few_autocomplete_manufacturers?
    Autocomplete::Loader.frame_mnfg_count < Manufacturer.frame_makers.count
  end
end
