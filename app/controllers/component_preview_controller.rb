# frozen_string_literal: true

# Used by ViewComponent/Lookbook previews to provide sortable table defaults
# that are normally set by the SortableTable concern in real controllers.
class ComponentPreviewController < ApplicationController
  helper_method :sort_column, :sort_direction

  def initialize
    super
    @period ||= "all"
  end

  def sort_column = params[:sort] || "id"
  def sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
end
