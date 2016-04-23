class PublicImagesController < ApplicationController
  before_filter :find_image_if_owned, only: [:edit, :update, :destroy, :is_private]

  def show
    @public_image = PublicImage.find(params[:id])
    if @public_image.present? && @public_image.imageable_type == 'Bike'
      @owner_viewing = true if @public_image.imageable.current_ownership.present? && @public_image.imageable.owner == current_user
    end
  end

  def create
    @public_image = PublicImage.new(params[:public_image])
    if params[:bike_id].present?
      @bike = Bike.unscoped.find(params[:bike_id])
      if @bike.owner == current_user
        @public_image.imageable = @bike
        @public_image.save
      end
      @imageable = @bike
    elsif params[:blog_id].present?
      @blog = Blog.find(params[:blog_id])
      @public_image.imageable = @blog
      @public_image.save
      @imageable = @blog
    end
    unless @public_image.imageable.present?
      flash[:error] = "Whoops! We can't let you create that image."
      redirect_to @imageable
    end
    render revised_layout_enabled? ? 'create_revised' : 'create'
  end

  def edit
  end

  def is_private
    @public_image.update_attribute :is_private, params[:is_private]
    render nothing: true
  end

  def update
    if @public_image.update_attributes(params[:public_image])
      redirect_to edit_bike_url(@public_image.imageable), notice: 'Image was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @imageable = @public_image.imageable
    imageable_id = @public_image.imageable_id
    imageable_type = @public_image.imageable_type
    @public_image.destroy
    flash[:notice] = 'Image was successfully deleted'
    if params[:page].present?
      redirect_to edit_bike_url(imageable_id, page: params[:page]) and return
    elsif imageable_type == 'Blog'
      redirect_to edit_admin_news_url(@imageable.title_slug) and return
    else
      redirect_to edit_bike_url(imageable_id)
    end
  end

  def order
    if params[:list_of_photos]
      last_image = params[:list_of_photos].count
      params[:list_of_photos].each_with_index do |id, index|
        image = PublicImage.unscoped.find(id)
        image.update_attribute :listing_order, index+1 if current_user_image_owner(image)
        next unless last_image == index && image.imageable_type == 'Bike'
        Bike.unscoped.find(image.imageable_id).save
      end
    end
    render nothing: true
  end

  protected

  def current_user_image_owner(public_image)
    if public_image.imageable_type == 'Bike'
      Bike.unscoped.find(public_image.imageable_id).owner == current_user
    elsif public_image.imageable_type == 'Blog'
      current_user && current_user.admin_authorized(content)
    end
  end

  def find_image_if_owned
    @public_image = PublicImage.unscoped.find(params[:id])
    unless current_user_image_owner(@public_image)
      flash[:error] = "Sorry! You don't have permission to edit that image."
      redirect_to @public_image.imageable and return
    end
  end
end
