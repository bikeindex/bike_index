class Bikes::EditsController < Bikes::BaseController
  include BikeEditable

  def show
    @page_errors = @bike.errors
    # NOTE: switched to edit_template param in #2040 (from page), because page is used for pagination
    return unless setup_edit_template(params[:edit_template] || params[:page]) # Returns nil if redirecting

    if @edit_template == "photos"
      @private_images = PublicImage
        .unscoped
        .where(imageable_type: "Bike")
        .where(imageable_id: @bike.id)
        .where(is_private: true)
    end

    render "/bikes_edit/#{@edit_template}".to_sym
  end

  private
end
