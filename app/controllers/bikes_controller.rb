class OwnershipNotSavedError < StandardError
end

class BikeNotSavedError < StandardError
end

class BikeCreatorError < StandardError
end

class BikeUpdatorError < StandardError
end

class BikeTyperError < StandardError
end

class BikesController < ApplicationController
  before_filter :find_bike, only: [:show, :edit, :update, :pdf]
  before_filter :ensure_user_allowed_to_edit, only: [:edit, :update, :pdf]
  before_filter :render_ad, only: [:index, :show]
  before_filter :set_return_to, only: [:edit]
  before_filter :remove_subdomain, only: [:index]
  layout 'no_container'

  def index
    params[:stolen] = true unless params[:stolen].present? || params[:non_stolen].present?
    if params[:proximity].present? && params[:proximity].strip.downcase == 'ip'
      params[:proximity] = request.env["HTTP_X_FORWARDED_FOR"].split(',')[0]
      # Geocoder.search(request.env["HTTP_X_FORWARDED_FOR"].split(',')[0])
    end
    search = BikeSearcher.new(params)
    bikes = search.find_bikes
    page = params[:page] || 1
    @per_page = params[:per_page] || 10
    bikes = bikes.page(page).per(@per_page)
    if params[:serial].present? && page == 1
      secondary_bikes = search.fuzzy_find_serial
      # secondary_bikes = search.find_bikes
      @secondary_bikes = secondary_bikes.decorate if secondary_bikes.present?
    end
    @bikes = bikes.decorate
    @query = params[:query]
    @query = request.query_parameters()
    @url = request.original_url
    @selectize_items = search.selectize_items
    render layout: 'application_updated'
  end

  def show
    @components = @bike.components.decorate
    if @bike.stolen and @bike.current_stolen_record.present?
      @stolen_record = @bike.current_stolen_record.decorate
    end
    @bike = @bike.decorate
    @stolen_notification = StolenNotification.new if @bike.stolen
    respond_to do |format|
      format.html { render layout: 'application_updated' }
      format.gif  { render qrcode: scanned_bike_url(@bike), level: :h, unit: 50 }
    end
  end

  def pdf
    unless bike.owner == current_user or current_user.is_member_of?(bike.creation_organization)
      flash[:error] = "Sorry, that's not your bike!"
      redirect_to bike_path(bike) and return
    end
    if bike.stolen and bike.current_stolen_record.present?
      @stolen_record = bike.current_stolen_record.decorate
    end
    @bike = bike.decorate
    filename = "Registration_" + @bike.updated_at.strftime("%m%d_%H%M")[0..-1]
    unless @bike.pdf.present? && @bike.pdf.file.filename == "#{filename}.pdf"
      pdf = render_to_string pdf: filename, template: 'bikes/pdf'
      save_path = "#{Rails.root}/tmp/#{filename}.pdf"
      File.open(save_path, 'wb') do |file|
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
    if params[:id]
      b = Bike.find(params[:id])
    else
      b = Bike.find_by_card_id(params[:card_id])
    end
    redirect_to bike_url(b) if b.present?
    @feedback = Feedback.new
    @card_id = params[:card_id]
  end

  def spokecard
    @qrcode = "#{bike_url(Bike.find(params[:id]))}.gif"
    render layout: false
  end

  def new
    if revised_layout_enabled?
      render_revised_new
    else
      if current_user.present?
        @b_param = BParam.create(creator_id: current_user.id, params: params)
        @b_param = BParam.create(creator_id: current_user.id, params: params)
        @bike = BikeCreator.new(@b_param).new_bike
      else
        @user = User.new
      end
      render layout: 'no_header'
    end
  end

  def render_revised_new
    find_or_new_b_param
    # Let them know if they sent an invalid b_param token
    flash[:notice] = "Sorry! We couldn't find that bike" if @b_param.id.blank? && params[:b_param_token].present?
    @bike ||= @b_param.bike_from_attrs(stolen: params[:stolen])
    render :new_revised, layout: 'application_revised'
  end

  def create
    if params[:bike][:embeded]
      @b_param = BParam.from_id_token(params[:bike][:b_param_id_token])
      @bike = Bike.new
      if @b_param.created_bike.present?
        redirect_to edit_bike_url(@bike)
      end
      if params[:bike][:image].present?
        @b_param.image = params[:bike][:image]
        @b_param.image_processed = false
        @b_param.save
        ImageAssociatorWorker.perform_in(1.minutes)
        params[:bike].delete(:image)
      end
      @b_param.update_attributes(params: params)
      @bike = BikeCreator.new(@b_param).create_bike
      if @bike.errors.any?
        @b_param.update_attributes(bike_errors: @bike.errors.full_messages)
        flash[:error] = @b_param.bike_errors.to_sentence
        if params[:bike][:embeded_extended]
          redirect_to embed_extended_organization_url(id: @bike.creation_organization.slug, b_param_id_token: @b_param.id_token) and return
        else
          redirect_to embed_organization_url(id: @bike.creation_organization.slug, b_param_id_token: @b_param.id_token) and return
        end
      else
        if params[:bike][:embeded_extended]
          flash[:notice] = "Success! #{@bike.type} was sent to #{@bike.owner_email}."
          persisted_email = params[:persist_email] ? @bike.owner_email : nil
          redirect_to embed_extended_organization_url(@bike.creation_organization, email: persisted_email) and return
        else
          redirect_to controller: :organizations, action: :embed_create_success, id: @bike.creation_organization.slug, bike_id: @bike.id and return
        end
      end
    elsif revised_layout_enabled?
      revised_create
    else
      @b_param = BParam.from_id_token(params[:bike][:b_param_id_token], "2014-12-31 18:00:00")
      unless @b_param && @b_param.creator_id == current_user.id
        @bike = Bike.new
        flash[:error] = "Oops, that isn't your bike"
        redirect_to action: :new, layout: 'no_header' and return
      end
      if @b_param.created_bike.present?
        redirect_to edit_bike_url(@b_param.created_bike) and return
      end
      @b_param.update_attributes(params: params)
      @bike = BikeCreator.new(@b_param).create_bike
      if @bike.errors.any?
        @b_param.update_attributes(bike_errors: @bike.errors.full_messages)
        render action: :new, layout: 'no_header' and return
      end
      redirect_to edit_bike_url(@bike), notice: "Bike successfully added to the index!"
    end
  end

  def revised_create
    find_or_new_b_param
    if @b_param.created_bike.present?
      redirect_to edit_bike_url(@b_param.created_bike) and return
    end
    @b_param.clean_params(params)
    @bike = BikeCreator.new(@b_param).create_bike
    if @bike.errors.any?
      @b_param.update_attributes(bike_errors: @bike.errors.full_messages)
      redirect_to new_bike_url(b_param_token: @b_param.id_token)
    else
      redirect_to edit_bike_url(@bike), notice: "Bike successfully added to the index!"
    end
  end


  def edit
    if revised_layout_enabled?
      @page_errors = @bike.errors
      @edit_template = edit_templates[params[:page]].present? ? params[:page] : edit_templates.keys.first
      render "edit_#{@edit_template}".to_sym, layout: 'application_revised'
    else
      @private_images = PublicImage.unscoped.where(imageable_type: 'Bike').where(imageable_id: @bike.id).where(is_private: true)
      @bike = @bike.decorate
    end
  end


  def update
    begin
      @bike = BikeUpdator.new(user: current_user, bike: @bike, b_params: params, current_ownership: @current_ownership).update_available_attributes
    rescue => e
      flash[:error] = e.message
      redirect_to bike_path(params[:id]) and return
    end
    @bike = @bike.decorate
    if @bike.errors.any?
      if revised_layout_enabled?
        @page_errors = @bike.errors
      else
        flash[:error] = @bike.errors.full_messages
      end
      render action: :edit
    else
      flash[:notice] = "Bike successfully updated!"
      return if return_to_if_present
      if params[:edit_template].present?
        redirect_to edit_bike_url(@bike, page: params[:edit_template]), layout: 'no_header' and return
      else
        redirect_to edit_bike_url(@bike), layout: 'no_header' and return
      end
    end
  end

  def edit_templates_hash
    hash = {
      root: 'Bike Details',
      photos: 'Photos',
      drivetrain: 'Wheels + Drivetrain',
      accessories: 'Accessories + Components',
      ownership: 'Change Owner or Delete',
      stolen: (@bike.stolen ? 'Theft details' : 'Report Stolen or Missing')
    }
    # To make stolen the first key if bike is stolen. using as_json for string keys instead of sym
    (@bike.stolen ? hash.to_a.rotate(-1).to_h : hash).as_json
  end

  def edit_templates
    @edit_templates ||= edit_templates_hash
  end

  protected

  def find_bike
    begin
      @bike = Bike.unscoped.find(params[:id])
    rescue ActiveRecord::StatementInvalid => e
      fail e.to_s =~ /PG..NumericValueOutOfRange/ ? ActiveRecord::RecordNotFound : e
    end
    if @bike.hidden
      unless current_user.present? && @bike.visible_by(current_user)
        flash[:error] = "Bike deleted"
        redirect_to root_url and return
      end
    end
  end

  def find_or_new_b_param
    token = params[:b_param_token]
    token ||= params[:bike] && params[:bike][:b_param_id_token]
    @b_param = BParam.find_or_new_from_token(token, user_id: current_user.id)
  end

  def ensure_user_allowed_to_edit
    @current_ownership = @bike.current_ownership
    type = @bike && @bike.type || 'bike'
    if current_user.present?
      unless @current_ownership && @current_ownership.owner == current_user
        error = "Oh no! It looks like you don't own that #{type}."
      end
    else
      if @current_ownership && @bike.current_ownership.claimed
        error = "Whoops! You have to sign in to be able to edit that #{type}."
      else
        error = "That #{type} hasn't been claimed yet. If it's your {type} sign up and you'll be able to edit it!"
      end
    end
    if error.present? # Can't assign directly to flash here, sometimes kick out of edit because other flash error
      flash[:error] = error
      redirect_to bike_path(@bike) and return
    end
  end

  def render_ad
    @ad = true
  end

  def remove_subdomain
    redirect_to bikes_url(subdomain: false) if request.subdomain.present?
  end
end
