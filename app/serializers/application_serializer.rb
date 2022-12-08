class ApplicationSerializer < ActiveModel::Serializer
  def cache_key
    object.cache_key_with_version
  end

  def perform_caching
    true
  end
end
