# NB: Decorators are deprecated in this project.
#     Use Helper methods for view logic, consider incrementally refactoring
#     existing view logic from decorators to view helpers.
class PaginatingDecorator < Draper::CollectionDecorator
  delegate :current_page, :total_pages, :limit_value
end
