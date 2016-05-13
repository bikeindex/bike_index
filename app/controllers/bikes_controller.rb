=begin
*****************************************************************
* File: app/controllers/bikes_controller.rb 
* Name: Class BikesController 
* Some methods to maneger the bike registration
*****************************************************************
=end

class OwnershipNotSavedError < StandardError
end

class BikeNotSavedError < StandardError

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

=begin
  Name: index 
  Explication: whats is going to show at bike index page. First select stolen bikes 
  neer to user (ip), search command so user can check for specifc bike. Than select bikes 
  from anywhere to show.
  Params: Bike params, page params
  Return: List with stolen bikes 
=end   
  def index
    params[:stolen] = true unless params[:stolen].present? || params[:non_stolen].present?
    if params[:proximity].present? && params[:proximity].strip.downcase == 'ip'
      params[:proximity] = request.env['HTTP_X_FORWARDED_FOR'].split(',')[0] if request.env['HTTP_X_FORWARDED_FOR']
    else
    end
    
    search = BikeSearcher.new(params)
    bikes = search.find_bikes
    asssert_message(search.find_bikes nil)
    
    page = params[:page] || 1
    @perPage = params[:perPage] || 10
    bikes = bikes.page(page).per(@perPage)
    if params[:serial].present? && page == 1
      secondaryBikes = search.fuzzy_find_serial
      @secondaryBikes = secondaryBikes.decorate if secondaryBikes.present?
    else
    end
    
    @bikes = bikes.decorate
    @query = params[:query]
    @query = request.query_parameters()
    @url = request.original_url
    @stolenness = search.stolenness_type
    @selectizeItems = search.selectizeItems
    if revised_layout_enabled?
      render :index_revised, layout: 'application_revised'
    else
      render layout: 'application_updated'
    end
  end

=begin
  Name: show
  Explication: show a list with all registrer bikes in website
  Params: bike params, stolen status
  Return: information about the stolen bikes according to the search of user 
=end 
  def show
    @components = @bike.components.decorate
    if @bike.stolen and @bike.current_stolenRecord.present?
      @stolenRecord = @bike.current_stolenRecord.decorate
    else
    end
    
    @bike = @bike.decorate
    @stolenNotification = StolenNotification.new if @bike.stolen
    respond_to do |format|
      format.html do
        if revised_layout_enabled?
          render :show_revised, layout: 'application_revised'
        else
          render layout: 'application_updated'
        end
      end
      format.gif  { render qrcode: scanned_bike_url(@bike), level: :h, unit: 50 }
    end
  end

 # What is method pdf ? 
  def pdf
    if @bike.stolen and @bike.current_stolenRecord.present?
      @stolenRecord = @bike.current_stolenRecord.decorate
    else
    end
    
    @bike = @bike.decorate
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

=begin
  Name: scanned
  Explication: scanned bike information to show to user
  Params: bike id
  Return: set al information about tha specific bike
=end  
  def scanned
    if params[:id]
      b = Bike.find(params[:id])
      assert(bike.find(params[:id]) == nil)
    
    else
      b = Bike.find_by_cardId(params[:cardId])
      assert(bike.find(params[:cardId]) == nil)
    end
    redirect_to bike_url(b) if b.present?
    @feedback = Feedback.new
    @cardId = params[:cardId]
  end

=begin
  Name: spokecard
  Explication: 
  Params: bike id
  Return:
=end  
  def spokecard
    @qrcode = "#{bike_url(Bike.find(params[:id]))}.gif"
    render layout: false
  end

=begin
  Name: new
  Explication: user can register a new bike  
  Params: id of creator, current_user id, 
  Return: if user logged in, create new bike, if not, redirect to sign up page
  Must discovery what's b_param  
=end  
  def new
    if revised_layout_enabled?
      new_revised
    else
      if current_user.present?
        @b_param = BParam.create(creator_id: current_user.id, params: params) # why he call this two times?
        @b_param = BParam.create(creator_id: current_user.id, params: params) # again?
        @bike = BikeCreator.new(@b_param).new_bike
      else
        @user = User.new
      end
      render layout: 'no_header'
    end
  end

=begin  
  Name: new_revised
  Explication: check if bike id was sent correctly
  Params: b_param id
  Return: if bike id not find, send a warning
=end  
  def new_revised
    find_or_new_b_param
    # Let them know if they sent an invalid b_param token
    flash[:notice] = "Sorry! We couldn't find that bike" if @b_param.id.blank? && params[:b_param_token].present?
    @bike ||= @b_param.bike_from_attrs(stolen: params[:stolen])
    @page_errors = @b_param.bike_errors
    render :new_revised, layout: 'application_revised'
  end

=begin
  Name: create
  Explication: create a bike with many check's if that bike id belongs to same user id 
  Params: bike 
  Return: new bike created correctly
  This method is to big, must aplly "one function, one action"  
=end 
  def create
    if params[:bike][:embeded]
      @b_param = BParam.from_id_token(params[:bike][:b_param_id_token])
      @bike = Bike.new

      create_bike_success

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
      else
      end
      @b_param.update_attributes(params: params)
      @bike = BikeCreator.new(@b_param).create_bike
      if @bike.errors.any?
        @b_param.update_attributes(bike_errors: @bike.errors.full_messages)
        render action: :new, layout: 'no_header' and return
      else
      end
      redirect_to edit_bike_url(@bike), notice: "Bike successfully added to the index!"
    end
  end

=begin
  Name: create_bike_success
  Explication: If user inform only valid values to create his bike he recive 
  a message and register his bike in data base
  Params: b_params  
=end 
  def create_bike_success
      if @b_param.created_bike.present?
         redirect_to edit_bike_url(@bike)
      else
      end
      if params[:bike][:image].present?
        @b_param.image = params[:bike][:image]
        @b_param.image_processed = false
        @b_param.save
        ImageAssociatorWorker.perform_in(1.minutes)
        params[:bike].delete(:image)
      else
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
  end

=begin
  Name: revised_create
  Explication: after create a new bike info user can revised the params 
  of new bike, and should confirm the info
  Params: b_param
  Return: user update the new bike, if everuthing it's ok he is redirect
  to the new bike url and recive a warning "Bike successfully update to the index!"  
=end 
  def revised_create
    find_or_new_b_param
    if @b_param.created_bike.present?
      redirect_to edit_bike_url(@b_param.created_bike) and return
    else
    end
    @b_param.clean_params(params)
    @bike = BikeCreator.new(@b_param).create_bike
    if @bike.errors.any?
      @b_param.update_attributes(bike_errors: @bike.errors.full_messages)
      redirect_to new_bike_url(b_param_token: @b_param.id_token)
    else
      redirect_to edit_bike_url(@bike), notice: "Bike successfully update to the index!"
    end
  end

=begin
  Name: edit
  Explication: render layout of edit bike and set errors messages
  Params: b_param
=end 
  def edit
    if revised_layout_enabled?
      @page_errors = @bike.errors
      @edit_template = edit_templates[params[:page]].present? ? params[:page] : edit_templates.keys.first
      if @edit_template == 'photos'
        @private_images = PublicImage.unscoped.where(imageable_type: 'Bike').where(imageable_id: @bike.id).where(is_private: true)
      else
      end
      render "edit_#{@edit_template}".to_sym, layout: 'application_revised'
    else
      @private_images = PublicImage.unscoped.where(imageable_type: 'Bike').where(imageable_id: @bike.id).where(is_private: true)
      @bike = @bike.decorate
    end
  end

=begin
  Name: edit
  Explication: render layout of edit bike and set errors messages
  Params: b_param
=end 
  def update
    begin
      @bike = BikeUpdator.new(user: current_user, bike: @bike, b_params: params, current_ownership: @current_ownership).update_available_attributes
    rescue => e
      flash[:error] = e.message
    end
    @bike = @bike.decorate
    if @bike.errors.any? || flash[:error].present?
      if revised_layout_enabled?
        edit and return
      else
        flash[:error] ||= @bike.errors.full_messages
        render action: :edit and return
      end
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

#  Name: edit_templates_hash
#  Explication: ronly set a hash of stolen bike
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

=begin
  Name: find_bike
  Explication: user can search the bike he has registred
  Params: bike id
=end 
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
    else
    end
  end

# ????????
  def find_or_new_b_param
    token = params[:b_param_token]
    token ||= params[:bike] && params[:bike][:b_param_id_token]
    @b_param = BParam.find_or_new_from_token(token, user_id: current_user.id)
  end

=begin
  Name: ensure_user_allowd_to_edit
  Explication:check if the ower of that bike is the current user
  Params: b_param, current_user
=end 
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
    else
    end
  end

  def render_ad
    @ad = true
  end

  def remove_subdomain
    redirect_to bikes_url(subdomain: false) if request.subdomain.present?
  end
end
