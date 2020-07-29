class ApplicationSerializer < ActiveModel::Serializer
  delegate :cache_key, to: :object

  # otherwise it's true, inexplicably. Manually override
  def perform_caching
    false
  end
end
