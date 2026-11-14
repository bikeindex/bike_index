# frozen_string_literal: true

# to_query, leaving the slashes in a catalog id, the commas joining a list and the braces and colons of what's picked for
# a vehicle readable, as Bike Book's JavaScript writes them
module ReadableQuery
  extend Functionable

  def path(path, query)
    return path if query.blank?

    "#{path}?#{query.to_query.gsub(/%2[CF]|%7[BD]|%3A/) { CGI.unescape(it) }}"
  end
end
