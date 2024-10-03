class MigrateBParamJsonbWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    5.minutes
  end

  def self.unmigrated
    BParam.where(params_jsonb: nil)
  end

  def perform(b_param_id = nil)
    return enqueue_workers unless b_param_id.present?

    b_param = BParam.find(b_param_id)
    new_params = b_param.params
    new_params["bike"]["cycle_type"] ||= "bike" if new_params["bike"].present?
    b_param.update_column :params_jsonb, new_params
  end

  def enqueue_workers
    self.class.unmigrated.limit(1000).pluck(:id).each do |id|
      self.class.perform_async(id)
    end
  end
end
