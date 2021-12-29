class ApplicationSerializer < ActiveModel::Serializer
  delegate :cache_key, to: :object

  def perform_caching
    true
  end
end
