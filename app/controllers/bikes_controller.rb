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
  before_filter :find_bike, only: [:show, :edit]
  before_filter :ensure_user_for_edit, only: [:edit, :update, :pdf]
  before_filter :render_ad, only: [:index, :show]
  before_filter :set_return_to, only: [:edit]
  layout 'no_container'

  def index
    params[:stolen] = true unless params[:stolen].present? || params[:non_stolen].present?
    if params[:proximity].present? && params[:proximity].strip.downcase == 'ip'
      params[:proximity] = request.env["HTTP_X_FORWARDED_FOR"].split(',')[0]
      # Geocoder.search(request.env["HTTP_X_FORWARDED_FOR"].split(',')[0])
    end
    search = BikeSearcher.new(params)
    bikes = search.find_bikes
    @count = bikes.count
    (bikes.count <= 250) ? (total_bikes = bikes.count) : (total_bikes = 250)
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
    bike = Bike.find(params[:id])
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
    if current_user.present?
      @b_param = BParam.create(creator_id: current_user.id, params: params)
      @bike = BikeCreator.new(@b_param).new_bike
    else
      @user = User.new
    end
    render layout: 'no_header'
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


  def edit
    begin
      BikeUpdator.new(user: current_user, b_params: params).ensure_ownership!
      rescue UserNotLoggedInError => e
        flash[:error] = e.message
        redirect_to new_user_path and return
      rescue => e
        flash[:error] = e.message
        redirect_to bike_path(@bike) and return
    end
    @private_images = PublicImage.unscoped.where(imageable_type: 'Bike').where(imageable_id: @bike.id).where(is_private: true)
    @bike = @bike.decorate
  end


  def update
    begin
      bike = BikeUpdator.new(user: current_user, b_params: params).update_available_attributes
    rescue => e
      flash[:error] = e.message
      redirect_to bike_path(params[:id]) and return
    end
    @bike = bike.decorate
    if bike.errors.any?
      flash[:error] = bike.errors.full_messages
      render action: :edit
    else
      flash[:notice] = "Bike successfully updated!"
      return if return_to_if_present
      if bike.stolen && params[:bike][:stolen] != false
        redirect_to edit_bike_url(@bike), layout: 'no_header' and return
      end
      redirect_to bike_url(@bike), layout: 'no_header' and return
    end
  end

protected

  def find_bike
    @bike = Bike.unscoped.find(params[:id])
    if @bike.hidden
      unless current_user.present? && @bike.visible_by(current_user)
        flash[:error] = "Bike deleted"
        redirect_to root_url and return
      end
    end
  end

  def ensure_user_for_edit
    unless current_user.present?
      if @bike.current_owner_exists
        flash[:error] = "Whoops! You have to sign in to be able to edit that #{@bike.type}."
      else
        flash[:error] = "That #{@bike.type} hasn't been claimed yet. If it's your bike sign up and you'll be able to edit it!"
      end
      redirect_to bike_path(@bike) and return
    end
  end

  def render_ad
    @ad = true
  end

end
