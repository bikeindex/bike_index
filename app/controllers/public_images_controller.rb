class PublicImagesController < ApplicationController
  before_action :find_image_if_owned, only: [:edit, :update, :destroy, :is_private]
  before_action :ensure_authorized_to_create!, only: [:create]

  def show
    @public_image = PublicImage.find(params[:id])
    if @public_image.present? && @public_image.imageable_type == "Bike"
      @owner_viewing = true if @public_image.imageable.current_ownership.present? && @public_image.imageable.owner == current_user
    end
  end

  def create
    @public_image = PublicImage.new(permitted_parameters)
    if params[:bike_id].present?
      @public_image.imageable = @bike
      @public_image.save
      render("create_revised") && return
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
      render(json: {public_image: @public_image}) && return
    end
    flash[:error] = translation(:cannot_create)
    redirect_to @public_image.present? ? @public_image.imageable : user_root_url
  end

  def edit
  end

  def is_private
    @public_image.update_attribute :is_private, params[:is_private]
    head :ok
  end

  def update
    if @public_image.update_attributes(permitted_parameters)
      redirect_to edit_bike_url(@public_image.imageable), notice: translation(:image_updated)
    else
      render :edit
    end
  end

  def destroy
    @imageable = @public_image.imageable
    imageable_id = @public_image.imageable_id
    imageable_type = @public_image.imageable_type
    if imageable_type == "MailSnippet"
      flash[:error] = translation(:cannot_delete)
      redirect_to(admin_organization_custom_layouts_path(imageable_id)) && return
    end
    @public_image.destroy
    flash[:success] = translation(:image_deleted)
    if params[:page].present?
      redirect_to(edit_bike_url(imageable_id, page: params[:page])) && return
    elsif imageable_type == "Blog"
      redirect_to(edit_admin_news_url(@imageable.title_slug), status: 303) && return
    else
      redirect_to edit_bike_url(imageable_id)
    end
  end

  def order
    params[:list_of_photos]&.each_with_index do |id, index|
      image = PublicImage.unscoped.find(id)
      image.update_attribute :listing_order, index + 1 if current_user_image_authorized(image)
    end
    head :ok
  end

  protected

  def ensure_authorized_to_create!
    if params[:bike_id].present? # Ensure the
      @bike = Bike.unscoped.find(params[:bike_id])
      return true if @bike.authorized?(current_user)
    end
    # Otherwise, it's a blog image or an organization image (or someone messing about),
    # so ensure the current user is admin authorized
    return true if current_user&.superuser?
    render(json: {error: "Access denied"}, status: 401) && return
  end

  def current_user_image_authorized(public_image)
    if public_image.imageable_type == "Bike"
      Bike.unscoped.find(public_image.imageable_id).authorized?(current_user)
    elsif public_image.imageable_type == "Blog" || public_image.imageable_type == "MailSnippet"
      current_user&.superuser?
    end
  end

  def permitted_parameters
    if params[:upload_plugin] == "uppy"
      {image: params[:file], name: params[:name]}
    else
      params.require(:public_image).permit(:image, :name, :imageable, :listing_order, :remote_image_url, :is_private)
    end
  end

  def find_image_if_owned
    @public_image = PublicImage.unscoped.find(params[:id])
    unless current_user_image_authorized(@public_image)
      flash[:error] = translation(:no_permission_to_edit)
      redirect_to(@public_image.imageable) && return
    end
  end
end
