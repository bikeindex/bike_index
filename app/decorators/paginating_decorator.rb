class PaginatingDecorator < Draper::CollectionDecorator
  delegate :current_page, :limit_value, :page, :per, :total_count, :total_pages
end
