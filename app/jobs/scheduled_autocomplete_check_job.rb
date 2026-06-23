# See PR#2483 - frequency can definitely be dropped a month or 2 after 2023-11
class ScheduledAutocompleteCheckJob < ScheduledJob
  prepend ScheduledJobRecorder

  # Set when a run finds too few manufacturers, so the next run knows it's a
  # repeat. TTL outlasts frequency to survive to the next scheduled run, but
  # clears itself if scheduling stalls (then the next failure self-heals quietly).
  MISSING_MANUFACTURERS_KEY = "scheduled_autocomplete_check_missing_manufacturers"

  def self.frequency
    4.minutes
  end

  def perform
    return clear_missing_flag unless too_few_autocomplete_manufacturers?

    # Kick off a reload and self-heal silently the first time; only raise if a
    # previous run already tried and the manufacturers are still missing.
    AutocompleteLoaderJob.perform_async
    was_missing = missing_flag?
    set_missing_flag
    raise "Missing Manufacturers!" if was_missing
  end

  def too_few_autocomplete_manufacturers?
    Autocomplete::Loader.frame_mnfg_count < Manufacturer.frame_makers.count
  end

  #
  # private below here
  #

  def missing_flag?
    RedisPool.conn { |r| r.get(MISSING_MANUFACTURERS_KEY).present? }
  end

  def set_missing_flag
    RedisPool.conn { |r| r.set(MISSING_MANUFACTURERS_KEY, Time.current.to_i, ex: self.class.frequency.to_i * 3) }
  end

  def clear_missing_flag
    RedisPool.conn { |r| r.del(MISSING_MANUFACTURERS_KEY) }
  end
end
