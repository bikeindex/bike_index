class Admin::BlogsController < Admin::BaseController
  before_filter :find_blog, only: [:show, :edit, :update, :destroy]

  def index
    @blogs = Blog.order("created_at asc")
  end

  def new
    @blog = Blog.new(post_date: Time.now, user_id: current_user.id)
    @users = User.all
  end

  def edit
    @users = User.all
  end

  def update
    if @blog.update_attributes(params[:blog])
      flash[:notice] = "Blog saved!"
      redirect_to edit_admin_blog_url(@blog)
    else
      render action: :edit
    end
  end

  def create
    @blog = Blog.create(params[:blog])
    if @blog.save
      flash[:notice] = "Blog created!"
      redirect_to admin_blogs_url
    else
      flash[:error] = "Blog Error!"
      redirect_to admin_blogs_url
    end
  end

  def destroy
    @blog.destroy
    redirect_to admin_blogs_url
  end

  protected

  def find_blog
    @blog = Blog.find_by_title_slug(params[:id])
  end
end
