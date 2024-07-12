class BikesController < Bikes::BaseController
  skip_before_action :verify_authenticity_token, only: %i[create]
  before_action :sign_in_if_not!, only: %i[show]
  before_action :render_ad, only: %i[index show]
  skip_before_action :find_bike, except: %i[show update pdf resolve_token]
  skip_before_action :assign_current_organization, except: %i[index show]
  skip_before_action :ensure_user_allowed_to_edit, except: %i[update pdf]
  around_action :set_reading_role, only: %i[index show]

  def index
    @interpreted_params = Bike.searchable_interpreted_params(permitted_search_params, ip: forwarded_ip_address)
    @stolenness = @interpreted_params[:stolenness]

    if params[:stolenness] == "proximity" && @stolenness != "proximity"
      flash[:info] = translation(:we_dont_know_location, location: params[:location])
    end
    page = (params[:page] || 1).to_i
    page = 1 if page > 100 # web search isn't meant for paging through everything. So block it
    @bikes = Bike.search(@interpreted_params).page(page).per(params[:per_page] || 10)
    @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)
  end

  def show
    redirect_to(format: "png") && return if request.format == "gif"
    if @bike.current_stolen_record.present?
      # Show contact owner box on load - happens if user has clicked on it and then logged in
      @contact_owner_open = @bike.contact_owner?(current_user) && params[:contact_owner].present?
      @stolen_record = @bike.current_stolen_record
    end
    if current_user.present? && BikeDisplayer.display_impound_claim?(@bike, current_user)
      impound_claims = @bike.impound_claims_claimed.where(user_id: current_user.id)
      @contact_owner_open = params[:contact_owner].present?
      @impound_claim = impound_claims.not_rejected.last
      @impound_claim ||= @bike.current_impound_record&.impound_claims&.build
      @submitted_impound_claims = impound_claims.where.not(id: @impound_claim.id).submitted
    end
    # These ivars are here primarily to make testing possible
    @passive_organization_registered = passive_organization.present? && @bike.organized?(passive_organization)
    @passive_organization_authorized = passive_organization.present? && @bike.authorized_by_organization?(org: passive_organization)
    if params[:scanned_id].present?
      @bike_sticker = BikeSticker.lookup_with_fallback(params[:scanned_id], organization_id: params[:organization_id], user: current_user)
    end
    find_token
    respond_to do |format|
      format.html { render :show }
      format.png do
        qrcode = RQRCode::QRCode.new(bike_url(@bike))
        render plain: qrcode.as_png(size: 1200, border_modules: 0), template: nil, format: :png
      end
    end
  end

  def pdf
    if @bike.current_stolen_record.present?
      @stolen_record = @bike.current_stolen_record
    end
    filename = "Registration_" + @bike.updated_at.strftime("%m%d_%H%M")[0..]
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
      redirect_to(bike_url(@bike_sticker.bike_id, scanned_id: params[:scanned_id], organization_id: params[:organization_id])) && return
    elsif current_user.present?
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      if current_user.member_of?(@bike_sticker.organization)
        set_passive_organization(@bike_sticker.organization)
        redirect_to(organization_bikes_path(organization_id: passive_organization.to_param, bike_sticker: @bike_sticker.code)) && return
      else
        @bikes = current_user.bikes.reorder(created_at: :desc).limit(100)
      end
    end
  end

  def spokecard
    @qrcode = "#{bike_url(Bike.find(params[:id]))}.png"
    render layout: false
  end

  def new
    unless current_user.present?
      store_return_to(new_bike_path(b_param_token: params[:b_param_token], stolen: params[:stolen]))
      flash[:info] = translation(:please_sign_in_to_register)
      redirect_to(new_user_path) && return
    end
    find_or_new_b_param
    redirect_to(bike_path(@b_param.created_bike_id)) && return if @b_param.created_bike.present?
    # Let them know if they sent an invalid b_param token - use flash#info rather than error because we're aggressive about removing b_params
    flash[:info] = translation(:we_couldnt_find_that_registration) if @b_param.id.blank? && params[:b_param_token].present?
    @bike ||= BikeCreator.new.build_bike(@b_param, BParam.bike_attrs_from_url_params(params.permit(:status, :stolen).to_h))
    # Fallback to active (i.e. passed organization_id), then passive_organization
    @bike.creation_organization ||= current_organization || passive_organization
    @organization = @bike.creation_organization
    @page_errors = @b_param.bike_errors
  end

  def create
    find_or_new_b_param
    org_param = (@b_param.organization || current_organization)&.slug # Protect from nil - see #2308
    if params.dig(:bike, :embeded).present? && org_param.present? # NOTE: if embeded, doesn't verify csrf token
      if @b_param.created_bike.present?
        redirect_to edit_bike_url(@b_param.created_bike)
      end
      if params[:bike][:image].present? # Have to do in the controller, before assigning
        @b_param.image = params[:bike].delete(:image) if params.dig(:bike, :image).present?
      end
      @b_param.update(params: permitted_bparams,
        origin: (params[:bike][:embeded_extended] ? "embed_extended" : "embed"))
      @bike = BikeCreator.new(ip_address: forwarded_ip_address).create_bike(@b_param)
      if @bike.errors.any?
        flash[:error] = @b_param.bike_errors.to_sentence
        if params[:bike][:embeded_extended]
          redirect_to(embed_extended_organization_url(id: org_param, b_param_id_token: @b_param.id_token)) && return
        else
          redirect_to(embed_organization_url(id: org_param, b_param_id_token: @b_param.id_token)) && return
        end
      elsif params[:bike][:embeded_extended]
        flash[:success] = translation(:bike_was_sent_to, bike_type: @bike.type, owner_email: @bike.owner_email)
        @persist_email = InputNormalizer.boolean(params[:persist_email])
        redirect_to(embed_extended_organization_url(org_param, email: @persist_email ? @bike.owner_email : nil)) && return
      else
        redirect_to(controller: :organizations, action: :embed_create_success, id: org_param, bike_id: @bike.id) && return
      end
    elsif verified_request?
      if @b_param.created_bike.present?
        redirect_to(edit_bike_url(@b_param.created_bike)) && return
      end
      @b_param.clean_params(permitted_bparams)
      @bike = BikeCreator.new(ip_address: forwarded_ip_address).create_bike(@b_param)
      if @bike.errors.any?
        redirect_to new_bike_url(b_param_token: @b_param.id_token)
      else
        flash[:success] = translation(:bike_was_added)
        redirect_to edit_bike_url(@bike)
      end
    else
      flash[:error] = "Unable to verify request, please sign in again"
      redirect_back(fallback_location: user_root_url)
    end
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

    if InputNormalizer.boolean(params[:organization_ids_can_edit_claimed_present]) || params.key?(:organization_ids_can_edit_claimed)
      update_organizations_can_edit_claimed(@bike, params[:organization_ids_can_edit_claimed])
    end
    assign_bike_stickers(params[:bike_sticker]) if params[:bike_sticker].present?
    @bike = @bike.reload

    @edit_templates = nil # update templates in case bike state has changed
    if @bike.errors.any? || flash[:error].present?
      edit_bike_url(@bike, edit_template: params[:edit_template])
    else
      flash[:success] ||= translation(:bike_was_updated)
      return if return_to_if_present
      # Go directly to theft_details after reporting stolen
      next_template = params[:edit_template]
      next_template = "theft_details" if next_template == "report_stolen" && @bike.status_stolen?
      redirect_to(edit_bike_url(@bike, edit_template: next_template)) && return
    end
  end

  def resolve_token
    if params[:token_type] == "graduated_notification"
      matching_notification = GraduatedNotification.where(bike_id: @bike.id, marked_remaining_link_token: params[:token]).first
      if matching_notification.present? && matching_notification.processed?
        if matching_notification.marked_remaining_at.blank?
          matching_notification.mark_remaining!(marked_remaining_by_id: current_user&.id)
        end
        flash[:success] = translation(:marked_remaining, bike_type: @bike.type)
      else
        flash[:error] = translation(:unable_to_find_graduated_notification)
      end
    else
      matching_notification = @bike.parking_notifications.where(retrieval_link_token: params[:token]).first
      if matching_notification.present?
        if matching_notification.active?
          flash[:success] = translation(:marked_retrieved, bike_type: @bike.type)
          # Quick hack to skip making another endpoint
          retrieved_kind = params[:user_recovery].present? ? "user_recovery" : "link_token_recovery"
          matching_notification.mark_retrieved!(retrieved_by_id: current_user&.id, retrieved_kind: retrieved_kind)
        elsif matching_notification.impounded? || matching_notification.impound_record_id.present?
          flash[:error] = translation(:notification_impounded, bike_type: @bike.type, org_name: matching_notification.organization.short_name)
        else
          # It's probably marked retrieved - but it could be something else (status: resolved_otherwise)
          flash[:info] = translation(:notification_already_retrieved, bike_type: @bike.type)
        end
      else
        flash[:error] = translation(:unable_to_find_parking_notification)
      end
    end

    redirect_to bike_path(@bike.id)
  end

  protected

  def render_ad
    @ad = true
  end
end
