class BikeVersions::EditsController < BikeVersionsController
  include BikeEditable

  def show
    @page_errors = @bike.errors
    return unless setup_edit_template(params[:edit_template]) # Returns nil if redirecting

    if @edit_template == "photos"
      @private_images = PublicImage
        .unscoped
        .where(imageable_type: "BikeVersion")
        .where(imageable_id: @bike_version.id)
        .where(is_private: true)
    end

    render "/bikes_edit/#{@edit_template}".to_sym
  end
end
