# frozen_string_literal: true

class ApplicationSerializer < ActiveModel::Serializer
  delegate :cache_key, to: :object

  def perform_caching; false end # otherwise it's true, inexplicably. Manually override
end
