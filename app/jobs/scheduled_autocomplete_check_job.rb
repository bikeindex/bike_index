# See PR#2483 for background
class ScheduledAutocompleteCheckJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    1.day
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
