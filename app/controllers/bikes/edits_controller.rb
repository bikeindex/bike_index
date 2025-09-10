# Note: Created this controller in #2133 so that it could be shared with bike_versions
# ... also because it was nice to break out the existing setup
class Bikes::EditsController < Bikes::BaseController
  include BikeEditable

  def show
    @page_errors = @bike.errors
    return unless setup_edit_template(params[:edit_template]) # Returns nil if redirecting

    @page_title = page_title_for(@edit_template, @bike)

    if @edit_template == "photos"
      @private_images = PublicImage
        .unscoped
        .where(imageable_type: "Bike")
        .where(imageable_id: @bike.id)
        .where(is_private: true)
    elsif @edit_template == "remove"
      @new_email_assigned = params[:owner_email].present? && @bike.owner_email != params[:owner_email]
      if @new_email_assigned
        @og_email = @bike.owner_email # so that edit_bike_skeleton doesn't show the wrong value
        @bike.owner_email = params[:owner_email]
      end
    end

    render :"/bikes_edit/#{@edit_template}"
  end

  private
end
