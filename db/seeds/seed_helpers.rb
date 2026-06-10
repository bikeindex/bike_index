# Shared helpers for the seed scripts
module SeedHelpers
  extend Functionable

  # Pick a frame maker weighted by priority (popular manufacturers chosen more
  # often), falling back to uniform when priorities are unset (e.g. fresh import)
  def weighted_frame_maker_id
    makers = Manufacturer.frame_makers.pluck(:id, :priority)
    total = makers.sum { |_id, priority| priority }
    return makers.sample.first if total.zero?

    target = rand(total)
    makers.find { |_id, priority| (target -= priority) < 0 }.first
  end
end
