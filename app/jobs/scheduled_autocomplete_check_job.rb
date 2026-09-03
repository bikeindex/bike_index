class ScheduledAutocompleteCheckJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    1.day
  end

  def perform
    return unless too_few_autocomplete_manufacturers?

    AutocompleteLoaderJob.new.perform
    raise "Missing Manufacturers!" if too_few_autocomplete_manufacturers?
  end

  private

  def too_few_autocomplete_manufacturers?
    Autocomplete::Loader.frame_mnfg_count < Manufacturer.frame_makers.count
  end
end
