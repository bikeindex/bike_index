=begin
*****************************************************************
* File: app/controllers/publicImages_controller.rb 
* Name: Class PublicImagesController 
* Set some methods to deal with images
*****************************************************************
=end

class PublicImagesController < ApplicationController
  before_filter :find_image_if_owned, only: [:edit, :update, :destroy, :is_private]

=begin
  Name: show
  Explication: method used to search and to display the specific public image desired.  
  Params: image's id
  Return: public image specific desired
=end
  def show
    publicImage = PublicImage.find(params[:id])
    if publicImage.present? && publicImage.imageable_type == 'Bike'
      @owner_viewing = true if publicImage.imageable.current_ownership.present? 
      && publicImage.imageable.owner == current_user
    else
      #nothing to do  
    end
  end

=begin
  Name: create
  Explication: method used to creation of a new public image.   
  Params: bike's id and params to create public image 
  Return: public image saved or nothing or to display the error message: "Whoops! We can't let you create that image" or render again layout to creation  
=end
  def create
    publicImage = PublicImage.new(params[:publicImage])
    if params[:bike_id].present?
      @bike = Bike.unscoped.find(params[:bike_id])
      assert_object_is_not_null(@bike)
      if @bike.owner == current_user
        publicImage.imageable = @bike
        publicImage.save
      else
        #nothing to do  
      end
      @imageable = @bike
      if params[:blog_id].present?
        @blog = Blog.find(params[:blog_id])
        assert_object_is_not_null(@blog)
        publicImage.imageable = @blog
        publicImage.save
        @imageable = @blog
      else
        #nothing to do
      end
    else
      render revised_layout_enabled? ? 'create_revised' : 'create'
    end  
    if publicImage.imageable.present?
      flash[:error] = "Whoops! We can't let you create that image."
      redirect_to @imageable
    else
      #nothing to do
    end
  end

=begin
  Name: edi
  Explication: empty method    
  Params: none
  Return: nothing
=end
  def edit
  end

=begin
  Name: is_private
  Explication: method used to update attributes presents in public images  
  Params: params is the own method name
  Return: nothing render
=end
  def is_private
    publicImage.update_attribute :is_private, params[:is_private]
    render nothing: true
  end

=begin
  Name: update
  Explication: method used to update attributes presents in public images and redirect if necessary  
  Params: params is the own method name
  Return: render edit page or redirect to edit bike page
=end
  def update
    if publicImage.update_attributes(params[:publicImage])
      redirect_to edit_bike_url(publicImage.imageable), notice: 'Image was successfully updated.'
    else
      render :edit
    end
  end

=begin
  Name: destroy
  Explication: method used to delete the image of the bike desired  
  Params: page related with the bikes
  Return: message: 'Image was successfully deleted' or redirect to edit bike or redirect to edit admin news
=end
  def destroy
    @imageable = publicImage.imageable
    assert_object_is_not_null(@imageable)
    imageable_id = publicImage.imageable_id
    imageable_type = publicImage.imageable_type
    publicImage.destroy
    flash[:notice] = 'Image was successfully deleted'
    if params[:page].present?
      redirect_to edit_bike_url(imageable_id, page: params[:page]) and return
    else
      #nothing to do
    end  
    if imageable_type == 'Blog'
      redirect_to edit_admin_news_url(@imageable.title_slug) and return
    else
      redirect_to edit_bike_url(imageable_id)
    end
  end

=begin
  Name: order
  Explication: method used to add a photo in the stolen bike  
  Params: list with all bike's photo
  Return: nothing render or bike's image
=end
  def order
    if params[:list_of_photos]
      last_image = params[:list_of_photos].count
      params[:list_of_photos].each_with_index do |id, index|
        image = PublicImage.unscoped.find(id)
        image.update_attribute :listing_order, index+1 if current_user_image_owner(image)
        next unless last_image == index && image.imageable_type == 'Bike'
        Bike.unscoped.find(image.imageable_id).save
      end
    else
      #nothing to do  
    end
    render nothing: true
  end

  protected

=begin
  Name: current_user_image_owner
  Explication: method user to associate the bike to your owner  
  Params: public image of the bike
  Return: bike or nothing or current user
=end
  def current_user_image_owner(publicImage)
    if publicImage.imageable_type == 'Bike'
      Bike.unscoped.find(publicImage.imageable_id).owner == current_user
    else
      #nothing to do
    if publicImage.imageable_type == 'Blog'
      current_user && current_user.admin_authorized(content)
    else
      #nothing to do
    end
  end

=begin
  Name: find_image_if_owned
  Explication: method used to associate a image the owner  
  Params: public image's id
  Return: redirect to public image or nothing
=end
  def find_image_if_owned
    publicImage = PublicImage.unscoped.find(params[:id])
    if current_user_image_owner(publicImage)
      flash[:error] = "Sorry! You don't have permission to edit that image."
      redirect_to publicImage.imageable and return
    else
      #nothing to do
    end
  end
end
