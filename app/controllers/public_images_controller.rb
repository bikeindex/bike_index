class PublicImagesController < ApplicationController
  before_filter :find_image_if_owned, only: [:edit, :update, :destroy, :is_private]
  before_filter :ensure_authorized_to_create!, only: [:create]

  def show
    @public_image = PublicImage.find(params[:id])
    if @public_image.present? && @public_image.imageable_type == 'Bike'
      @owner_viewing = true if @public_image.imageable.current_ownership.present? && @public_image.imageable.owner == current_user
    end
  end

  def create
    @public_image = PublicImage.new(permitted_parameters)
    if params[:bike_id].present?
      @public_image.imageable = @bike
      @public_image.save
      render 'create_revised' and return
    else
      if params[:blog_id].present?
        @blog = Blog.find(params[:blog_id])
        @public_image.imageable = @blog
      elsif params[:mail_snippet_id]
        @public_image.imageable = MailSnippet.find(params[:mail_snippet_id])
      else
        @public_image.imageable = current_organization
      end
      @public_image.save
      render 'create' and return
    end
    flash[:error] = "Whoops! We can't let you create that image."
    redirect_to @public_image.present? ? @public_image.imageable : user_root_url
  end

  def edit
  end

  def is_private
    @public_image.update_attribute :is_private, params[:is_private]
    render nothing: true
  end

  def update
    if @public_image.update_attributes(permitted_parameters)
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
    flash[:success] = 'Image was successfully deleted'
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
      params[:list_of_photos].each_with_index do |id, index|
        image = PublicImage.unscoped.find(id)
        image.update_attribute :listing_order, index + 1 if current_user_image_owner(image)
      end
    end
    render nothing: true
  end

  protected

  def ensure_authorized_to_create!
    if params[:bike_id].present? # Ensure the
      @bike = Bike.unscoped.find(params[:bike_id])
      return true if @bike.owner == current_user
    end
    # Otherwise, it's a blog image or an organization image (or someone messing about),
    # so ensure the current user is admin authorized
    return true if current_user && current_user.admin_authorized('any')
    render json: { error: 'Access denied' }, status: 401 and return
  end

  def current_user_image_owner(public_image)
    if public_image.imageable_type == 'Bike'
      Bike.unscoped.find(public_image.imageable_id).owner == current_user
    elsif public_image.imageable_type == 'Blog'
      current_user && current_user.admin_authorized('content')
    end
  end

  def permitted_parameters
    params.require(:public_image).permit(PublicImage.old_attr_accessible)
  end

  def find_image_if_owned
    @public_image = PublicImage.unscoped.find(params[:id])
    unless current_user_image_owner(@public_image)
      flash[:error] = "Sorry! You don't have permission to edit that image."
      redirect_to @public_image.imageable and return
    end
  end
end
