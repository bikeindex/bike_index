module BikeEditable
  extend ActiveSupport::Concern

  included do
    helper_method :sort_column, :sort_direction
  end

  def sort_column
    sortable_columns.include?(params[:sort]) ? params[:sort] : default_column
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : default_direction
  end

  # So it can be overridden
  def default_direction
    "desc"
  end

  def default_column
    sortable_columns.first
  end
end
