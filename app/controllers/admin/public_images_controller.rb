# frozen_string_literal: true

module Admin
  class PublicImagesController < Admin::BaseController
    include Binxtils::SortableTable

    def index
      @per_page = permitted_per_page(default: 25)
      @pagy, @collection = pagy(:countish,
        matching_public_images.includes(:imageable)
          .reorder("public_images.#{sort_column} #{sort_direction}"),
        limit: @per_page,
        page: permitted_page)
    end

    helper_method :matching_public_images

    protected

    def sortable_columns
      %w[created_at updated_at imageable_type kind].freeze
    end

    def earliest_period_date
      Time.at(1373500800) # 2013-07-11 - first public image
    end

    # unscoped so admins see private images too
    def matching_public_images
      public_images = PublicImage.unscoped
      @imageable_type = params[:search_imageable_type] if PublicImage::IMAGEABLE_TYPES.include?(params[:search_imageable_type])
      public_images = public_images.where(imageable_type: @imageable_type) if @imageable_type.present?

      @kind = params[:search_kind] if PublicImage.kinds.include?(params[:search_kind])
      public_images = public_images.where(kind: @kind) if @kind.present?

      @private = Binxtils::InputNormalizer.boolean(params[:search_private])
      public_images = public_images.where(is_private: true) if @private

      @time_range_column = (sort_column == "updated_at") ? sort_column : "created_at"
      public_images.where(@time_range_column => @time_range)
    end
  end
end
