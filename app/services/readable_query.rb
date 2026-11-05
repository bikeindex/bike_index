# frozen_string_literal: true

# to_query, leaving the slashes in a catalog id and the commas joining a list readable, as BikeBook's JavaScript writes them
module ReadableQuery
  extend Functionable

  def path(path, query)
    return path if query.blank?

    "#{path}?#{query.to_query.gsub("%2F", "/").gsub("%2C", ",")}"
  end
end
