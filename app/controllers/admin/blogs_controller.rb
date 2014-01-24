class Admin::BlogsController < Admin::BaseController
  before_filter :find_blog, only: [:show, :edit, :update, :destroy]

  def index
    @blogs = Blog.order("created_at asc")
  end

  def new
    @blog = Blog.new(published_at: Time.now, user_id: current_user.id)
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
    @blog = Blog.create({
      title: params[:blog][:title],
      user_id: current_user.id,
      body: "No content yet, write some now!",
      published_at: Time.now
    })
    if @blog.save
      flash[:notice] = "Blog created!"
      redirect_to edit_admin_blog_url(@blog)
    else
      flash[:error] = "Blog error!"
      redirect_to new_admin_blog_url
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
