class OwnershipNotSavedError < StandardError
end

class BikeUpdatorError < StandardError
end

class BikesController < ApplicationController
  before_action :find_bike, only: [:show, :edit, :update, :pdf]
  before_action :ensure_user_allowed_to_edit, only: [:edit, :update, :pdf]
  before_action :render_ad, only: [:index, :show]
  before_action :store_return_to, only: [:edit]
  before_action :remove_subdomain, only: [:index]
  before_action :assign_current_organization, only: [:index, :show, :edit]

  def index
    @interpreted_params = Bike.searchable_interpreted_params(permitted_search_params, ip: forwarded_ip_address)
    @stolenness = @interpreted_params[:stolenness]

    if params[:stolenness] == "proximity" && @stolenness != "proximity"
      flash[:info] = translation(:we_dont_know_location, location: params[:location])
    end

    @bikes = Bike.search(@interpreted_params).page(params[:page] || 1).per(params[:per_page] || 10).decorate
    @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)
  end

  def show
    @components = @bike.components
    if @bike.stolen and @bike.current_stolen_record.present?
      # Show contact owner box on load - happens if user has clicked on it and then logged in
      @contact_owner_open = @bike.contact_owner?(current_user) && params[:contact_owner].present?
      @stolen_record = @bike.current_stolen_record
    end

    @bike = @bike.decorate
    if params[:scanned_id].present?
      @bike_sticker = BikeSticker.lookup_with_fallback(params[:scanned_id], organization_id: params[:organization_id], user: current_user)
    end
    if params[:parking_notification_retrieved].present?
      resolve_parking_notification(params[:parking_notification_retrieved])
    else
      respond_to do |format|
        format.html { render :show }
        format.gif { render qrcode: bike_url(@bike), level: :h, unit: 50 }
      end
    end
  end

  def pdf
    if @bike.stolen and @bike.current_stolen_record.present?
      @stolen_record = @bike.current_stolen_record
    end
    @bike = @bike.decorate
    filename = "Registration_" + @bike.updated_at.strftime("%m%d_%H%M")[0..-1]
    unless @bike.pdf.present? && @bike.pdf.file.filename == "#{filename}.pdf"
      pdf = render_to_string pdf: filename, template: "bikes/pdf"
      save_path = "#{Rails.root}/tmp/#{filename}.pdf"
      File.open(save_path, "wb") do |file|
        file << pdf
      end
      # @bike.pdf = File.open(pdf, 'wb') { |file| file << pdf }
      @bike.pdf = File.open(save_path)
      @bike.save
    end
    # render pdf: 'registration_pdf', show_as_html: true
    redirect_to @bike.pdf.url
  end

  def scanned
    @bike_sticker = BikeSticker.lookup_with_fallback(scanned_id, organization_id: params[:organization_id], user: current_user)
    if @bike_sticker.blank?
      flash[:error] = translation(:unable_to_find_sticker, scanned_id: params[:scanned_id])
      redirect_to user_root_url
    elsif @bike_sticker.bike.present?
      redirect_to bike_url(@bike_sticker.bike_id, scanned_id: params[:scanned_id], organization_id: params[:organization_id]) and return
    elsif current_user.present?
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      if current_user.member_of?(@bike_sticker.organization)
        set_passive_organization(@bike_sticker.organization)
        redirect_to organization_bikes_path(organization_id: passive_organization.to_param, bike_sticker: @bike_sticker.code) and return
      else
        @bikes = current_user.bikes.reorder(created_at: :desc).limit(100)
      end
    end
  end

  def spokecard
    @qrcode = "#{bike_url(Bike.find(params[:id]))}.gif"
    render layout: false
  end

  def new
    unless current_user.present?
      store_return_to(new_bike_path(b_param_token: params[:b_param_token], stolen: params[:stolen]))
      flash[:info] = translation(:please_sign_in_to_register)
      redirect_to new_user_path and return
    end
    find_or_new_b_param
    redirect_to bike_path(@b_param.created_bike_id) and return if @b_param.created_bike.present?
    # Let them know if they sent an invalid b_param token - use flash#info rather than error because we're aggressive about removing b_params
    flash[:info] = translation(:we_couldnt_find_that_registration) if @b_param.id.blank? && params[:b_param_token].present?
    @bike ||= @b_param.bike_from_attrs(is_stolen: params[:stolen], abandoned: params[:abandoned])
    # Fallback to active (i.e. passed organization_id), then passive_organization
    @bike.creation_organization ||= current_organization || passive_organization
    @organization = @bike.creation_organization
    if @bike.stolen
      @stolen_record = @bike.stolen_records.build(@b_param.params["stolen_record"])
      @stolen_record.country_id ||= Country.united_states.id
    end
    @page_errors = @b_param.bike_errors
  end

  def create
    find_or_new_b_param
    if params[:bike][:embeded]
      if @b_param.created_bike.present?
        redirect_to edit_bike_url(@b_param.created_bike)
      end
      if params[:bike][:image].present?
        @b_param.image = params[:bike][:image]
        @b_param.image_processed = false # Don't need to save because update below
        ImageAssociatorWorker.perform_in(1.minutes)
        params[:bike].delete(:image)
      end
      @b_param.update_attributes(params: permitted_bparams,
                                 origin: (params[:bike][:embeded_extended] ? "embed_extended" : "embed"))
      @bike = BikeCreator.new(@b_param, location: request.safe_location).create_bike
      if @bike.errors.any?
        @b_param.update_attributes(bike_errors: @bike.cleaned_error_messages)
        flash[:error] = @b_param.bike_errors.to_sentence
        if params[:bike][:embeded_extended]
          redirect_to embed_extended_organization_url(id: @bike.creation_organization.slug, b_param_id_token: @b_param.id_token) and return
        else
          redirect_to embed_organization_url(id: @bike.creation_organization.slug, b_param_id_token: @b_param.id_token) and return
        end
      else
        if params[:bike][:embeded_extended]
          flash[:success] = translation(:bike_was_sent_to, bike_type: @bike.type, owner_email: @bike.owner_email)
          @persist_email = ParamsNormalizer.boolean(params[:persist_email])
          redirect_to embed_extended_organization_url(@bike.creation_organization, email: @persist_email ? @bike.owner_email : nil) and return
        else
          redirect_to controller: :organizations, action: :embed_create_success, id: @bike.creation_organization.slug, bike_id: @bike.id and return
        end
      end
    else
      if @b_param.created_bike.present?
        redirect_to edit_bike_url(@b_param.created_bike) and return
      end
      @b_param.clean_params(permitted_bparams)
      @bike = BikeCreator.new(@b_param).create_bike
      if @bike.errors.any?
        @b_param.update_attributes(bike_errors: @bike.cleaned_error_messages)
        redirect_to new_bike_url(b_param_token: @b_param.id_token)
      else
        flash[:success] = translation(:bike_was_added)
        redirect_to edit_bike_url(@bike)
      end
    end
  end

  def edit
    @page_errors = @bike.errors
    @edit_templates = edit_templates

    requested_page = target_edit_template(requested_page: params[:page])
    @edit_template = requested_page[:template]
    if !requested_page[:is_valid]
      redirect_to edit_bike_url(@bike, page: @edit_template) and return
    end

    case @edit_template
    when "photos"
      @private_images =
        PublicImage
          .unscoped
          .where(imageable_type: "Bike")
          .where(imageable_id: @bike.id)
          .where(is_private: true)
    when /alert/
      unless @bike&.current_stolen_record.present?
        redirect_to edit_bike_url(@bike, page: @edit_template) and return
      end

      bike_image = PublicImage.find_by(id: params[:selected_bike_image_id])
      @bike.current_stolen_record.generate_alert_image(bike_image: bike_image)

      @theft_alert_plans = TheftAlertPlan.active.price_ordered_asc.in_language(I18n.locale)
      @selected_theft_alert_plan =
        @theft_alert_plans.find_by(id: params[:selected_plan_id]) ||
        @theft_alert_plans.min_by(&:amount_cents)

      @theft_alerts =
        @bike
          .current_stolen_record
          .theft_alerts
          .includes(:theft_alert_plan)
          .creation_ordered_desc
          .where(creator: current_user)
          .references(:theft_alert_plan)
    end

    render "edit_#{@edit_template}".to_sym
  end

  def update
    begin
      @bike = BikeUpdator.new(user: current_user, bike: @bike, b_params: permitted_bike_params.as_json, current_ownership: @current_ownership).update_available_attributes
    rescue => e
      flash[:error] = e.message
    end
    if ParamsNormalizer.boolean(params[:organization_ids_can_edit_claimed_present]) || params.key?(:organization_ids_can_edit_claimed)
      update_organizations_can_edit_claimed(@bike, params[:organization_ids_can_edit_claimed])
    end
    assign_bike_stickers(params[:bike_sticker]) if params[:bike_sticker].present?
    @bike = @bike.decorate

    if @bike.errors.any? || flash[:error].present?
      edit and return
    else
      flash[:success] ||= translation(:bike_was_updated)
      return if return_to_if_present
      redirect_to edit_bike_url(@bike, page: params[:edit_template]) and return
    end
  end

  def edit_templates
    return @edit_templates if defined?(@edit_templates)
    @theft_templates = @bike.stolen? ? theft_templates : {}
    @bike_templates = bike_templates
    @edit_templates = @theft_templates.merge(@bike_templates)
  end

  protected

  # Determine the appropriate edit template to use in the edit view.
  #
  # If provided an invalid template name, return the default page for a stolen /
  # unstolen bike and `:is_valid` mapped to false.
  #
  # Return a Hash with keys :is_valid (boolean), :template (string)
  def target_edit_template(requested_page:)
    result = {}
    valid_pages = [*edit_templates.keys, "alert_purchase", "alert_purchase_confirmation"]
    default_page = @bike.stolen? ? :theft_details : :bike_details

    case
    when requested_page.blank?
      result[:is_valid] = true
      result[:template] = default_page.to_s
    when requested_page.in?(valid_pages)
      result[:is_valid] = true
      result[:template] = requested_page.to_s
    else
      result[:is_valid] = false
      result[:template] = default_page.to_s
    end

    result
  end

  # NB: Hash insertion order here determines how nav links are displayed in the
  # UI. Keys also correspond to template names and query parameters, and values
  # are used as haml header tag text in the corresponding templates.
  def theft_templates
    {}.with_indifferent_access.tap do |h|
      h[:theft_details] = translation(:recovery_details, controller_method: :edit) if @bike.abandoned?
      h[:theft_details] = translation(:theft_details, controller_method: :edit) unless @bike.abandoned?
      h[:publicize] = translation(:publicize, controller_method: :edit)
      h[:alert] = translation(:alert, controller_method: :edit)
      h[:report_recovered] = translation(:report_recovered, controller_method: :edit) unless @bike.abandoned?
    end
  end

  # NB: Hash insertion order here determines how nav links are displayed in the
  # UI. Keys also correspond to template names and query parameters, and values
  # are used as haml header tag text in the corresponding templates.
  def bike_templates
    {}.with_indifferent_access.tap do |h|
      h[:bike_details] = translation(:bike_details, controller_method: :edit)
      h[:photos] = translation(:photos, controller_method: :edit)
      h[:drivetrain] = translation(:drivetrain, controller_method: :edit)
      h[:accessories] = translation(:accessories, controller_method: :edit)
      h[:ownership] = translation(:ownership, controller_method: :edit)
      h[:groups] = translation(:groups, controller_method: :edit)
      h[:remove] = translation(:remove, controller_method: :edit)
      h[:report_stolen] = translation(:report_stolen, controller_method: :edit) unless @bike.stolen?
    end
  end

  # Make it possible to assign organization for a view by passing the organization_id parameter - mainly useful for superusers
  # Also provides testable protection against seeing organization info on bikes
  def assign_current_organization
    org = current_organization || passive_organization
    # If current_user isn't authorized for the organization, force assign nil
    return true if org.blank? || org.present? && current_user&.authorized?(org)
    set_passive_organization(nil)
  end

  def permitted_search_params
    params.permit(*Bike.permitted_search_params)
  end

  def find_bike
    begin
      @bike = Bike.unscoped.find(params[:id])
    rescue ActiveRecord::StatementInvalid => e
      fail e.to_s =~ /PG..NumericValueOutOfRange/ ? ActiveRecord::RecordNotFound : e
    end
    if @bike.hidden || @bike.deleted?
      return @bike if current_user.present? && @bike.visible_by?(current_user)
      fail ActiveRecord::RecordNotFound
    end
  end

  def find_or_new_b_param
    token = params[:b_param_token]
    token ||= params[:bike] && params[:bike][:b_param_id_token]
    @b_param = BParam.find_or_new_from_token(token, user_id: current_user && current_user.id)
  end

  def ensure_user_allowed_to_edit
    @current_ownership = @bike.current_ownership
    type = @bike&.type || "bike"

    return true if @bike.authorize_and_claim_for_user(current_user)

    if current_user.present?
      error = translation(:you_dont_own_that, bike_type: type)
    else
      if @current_ownership && @bike.current_ownership.claimed
        error = translation(:you_have_to_sign_in, bike_type: type)
      else
        error = translation(:bike_has_not_been_claimed_yet, bike_type: type)
      end
    end

    if error.present? # Can't assign directly to flash here, sometimes kick out of edit because other flash error
      flash[:error] = error
      redirect_to bike_path(@bike) and return
    end

    authenticate_user(translation_key: :create_account, flash_type: :info)
  end

  def update_organizations_can_edit_claimed(bike, organization_ids)
    organization_ids = organization_ids.presence.to_a.map(&:to_i)
    bike.bike_organizations.each do |bike_organization|
      bike_organization.update_attribute :can_not_edit_claimed, !organization_ids.include?(bike_organization.organization_id)
    end
  end

  def assign_bike_stickers(bike_sticker)
    bike_sticker = BikeSticker.lookup_with_fallback(bike_sticker)
    return flash[:error] = translation(:unable_to_find_sticker, bike_sticker: bike_sticker) unless bike_sticker.present?
    if bike_sticker.claim_if_permitted(current_user, @bike)
      flash[:success] = translation(:sticker_assigned, bike_sticker: bike_sticker.pretty_code, bike_type: @bike.type)
    else
      flash[:error] = bike_sticker.errors.full_messages
    end
  end

  def resolve_parking_notification(retrieval_link_token)
    matching_notification = @bike.parking_notifications.where(retrieval_link_token: retrieval_link_token).first
    if matching_notification.present?
      if matching_notification.active?
        flash[:success] = "That #{@bike.type} has already been marked retrieved!"
        matching_notification.mark_retrieved!(current_user&.id, "link_token_recovery")
      elsif matching_notification.impounded?
        flash[:error] = "That #{@bike.type} has been impounded! Contact #{matching_notification.organization.short_name} to retrieve it."
      elsif matching_notification.retrieved?
        flash[:info] = "That #{@bike.type} has already been marked retrieved!"
      end
    else
      flash[:error] = "Unable to find that Parking Notification!"
    end
    redirect_to bike_path(params.except(:parking_notification_retrieved)) and return
  end

  def render_ad
    @ad = true
  end

  def scanned_id
    params[:id] || params[:scanned_id] || params[:card_id]
  end

  def remove_subdomain
    redirect_to bikes_url(subdomain: false) if request.subdomain.present?
  end

  def permitted_bike_params
    { bike: params.require(:bike).permit(Bike.old_attr_accessible) }
  end

  def permitted_bparams # still manually managing permission of params, so skip it
    params.except(:parking_notification).as_json # We only want to include parking_notification in authorized endpoints
  end
end
