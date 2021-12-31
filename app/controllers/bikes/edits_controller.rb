# Note: Created this controller in #2133 so that it could be shared with bike_versions
# ... also because it was nice to break out the existing setup
class Bikes::EditsController < Bikes::BaseController
  include BikeEditable

  def show
    @page_errors = @bike.errors
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
