class PublicImagesController < ApplicationController
  before_filter :find_image_if_owned, only: [:edit, :update, :destroy]

  def index
    @public_images = PublicImage.all 
  end

  def show
    @public_image = PublicImage.find(params[:id])
  end

  def create
    @public_image = PublicImage.new(params[:public_image])
    if params[:bike_id].present?
      @bike = Bike.find(params[:bike_id])
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
  end

  def edit
  end

  def update
    if @public_image.update_attributes(params[:public_image])
      redirect_to edit_bike_url(@public_image.imageable), notice: "Image was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    @imageable = @public_image.imageable if @public_image.imageable_type == "Bike"
    @public_image.destroy
    flash[:notice] = "Image was successfully deleted"
    if params[:return_url].present?
      redirect_to params[:return_url]
    else
      redirect_to edit_bike_url(@imageable) and return if @imageable.cycle_type_id
      redirect_to edit_admin_news(@imageable)
    end
  end

  def order

    if params[:list_of_photos]
      params[:list_of_photos].each_with_index do |id, index|
        PublicImage.update_all({listing_order: index+1}, {id: id})
      end
      i = PublicImage.find(params[:list_of_photos].last)
      if i.imageable_type == "Bike" # if it's a bike save the bike to update cached thumbnail
        i.imageable.save
      end
    end
    render nothing: true
  end

  protected

  def find_image_if_owned
    @public_image = PublicImage.find(params[:id])
    if @public_image.imageable_type == "Bike"
      unless @public_image.imageable.owner == current_user
        flash[:error] = "Sorry! You don't have permission to edit that image."
        redirect_to @public_image.imageable and return
      end
    elsif @public_image.imageable_type == "Blog"
      unless current_user.superuser? 
        flash[:error] = "Sorry! You don't have permission to edit that image."
        redirect_to @public_image.imageable and return
      end
    end
  end
    
end
