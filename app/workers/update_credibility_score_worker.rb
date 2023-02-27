# Migration job to backfill credibility scores on bikes

class UpdateCredibilityScoreWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  sidekiq_options retry: false

  def self.frequency
    10.minutes
  end

  def perform(bike_id = nil)
    return enqueue_workers if bike_id.nil?
    bike = Bike.unscoped.where(id: bike_id).first
    bike.update_column :credibility_score, bike.credibility_scorer.score
  end

  def enqueue_workers
    Bike.unscoped.where(credibility_score: nil).order(created_at: :desc).limit(500)
      .pluck(:id).each { |i| UpdateCredibilityScoreWorker.perform_async(i) }
  end
end
