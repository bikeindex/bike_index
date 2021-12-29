class BikeVersionsController < ApplicationController
  before_action :render_ad, only: %i[index show]
  before_action :find_bike_version, except: %i[index new create]
  before_action :ensure_user_allowed_to_edit, only: %i[edit update]

  def index
  end

  def show
  end

  def new
  end

  def create
  end

  def edit
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

    render "edit_#{@edit_template}".to_sym
  end

  def update
    if params[:bike].present?
      begin
        @bike = BikeUpdator.new(user: current_user, bike: @bike, b_params: permitted_bike_params.as_json, current_ownership: @current_ownership).update_available_attributes
      rescue => e
        flash[:error] = e.message
        # Sometimes, weird things error. In production, Don't show a 500 page to the user
        # ... but in testing or development re-raise error to make stack tracing better
        raise e unless Rails.env.production?
      end
    end

    if ParamsNormalizer.boolean(params[:organization_ids_can_edit_claimed_present]) || params.key?(:organization_ids_can_edit_claimed)
      update_organizations_can_edit_claimed(@bike, params[:organization_ids_can_edit_claimed])
    end
    assign_bike_stickers(params[:bike_sticker]) if params[:bike_sticker].present?
    @bike = @bike.reload

    @edit_templates = nil # update templates in case bike state has changed
    if @bike.errors.any? || flash[:error].present?
      edit
    else
      flash[:success] ||= translation(:bike_was_updated)
      return if return_to_if_present
      # Go directly to theft_details after reporting stolen
      next_template = params[:edit_template] || params[:page]
      next_template = "theft_details" if next_template == "report_stolen" && @bike.status_stolen?
      redirect_to(edit_bike_url(@bike, edit_template: next_template)) && return
    end
  end

  protected

  def find_bike_version
    begin
      @bike_version = BikeVersion.unscoped.find(params[:id])
    rescue ActiveRecord::StatementInvalid => e
      raise e.to_s.match?(/PG..NumericValueOutOfRange/) ? ActiveRecord::RecordNotFound : e
    end
    return @bike_version if @bike_version.visible_by?(current_user)
    fail ActiveRecord::RecordNotFound
  end

  def ensure_user_allowed_to_edit
    return true if @bike.authorized?(current_user)
  end

  def render_ad
    @ad = true
  end
end
