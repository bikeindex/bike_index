# Shared helpers for the seed scripts
module SeedHelpers
  extend Functionable

  # Pick a frame maker weighted by priority (popular manufacturers chosen most
  # often), with the long tail of unprioritized makers appearing ~8% of the
  # time. Falls back to uniform when no priorities are set (e.g. fresh import).
  def weighted_frame_maker_id
    makers = Manufacturer.frame_makers.pluck(:id, :priority)
    prioritized = makers.select { |_id, priority| priority.to_i.positive? }
    return makers.sample.first if prioritized.empty?

    tail = makers - prioritized
    return tail.sample.first if tail.any? && rand < 0.08

    total = prioritized.sum { |_id, priority| priority }
    target = rand(total)
    prioritized.find { |_id, priority| (target -= priority) < 0 }.first
  end
end
