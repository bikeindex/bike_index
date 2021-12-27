class ApplicationSerializer < ActiveModel::Serializer
  delegate :cache_key, to: :object

  # TODO: after #2123, switch this to cache!
  def perform_caching
    false
  end
end
