module FeatureFlaggable
  extend ActiveSupport::Concern

  # Unique id used for feature flagging
  def feature_flag_id
    "#{self.class.name}:#{id}"
  end

  alias flipper_id feature_flag_id
end
