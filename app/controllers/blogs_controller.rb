class BlogsController < ApplicationController
  layout 'content'
  before_filter :set_blogs_active_section

  def show
    @blog = Blog.find_by_title_slug(params[:id])
    @blog = Blog.find_by_old_title_slug(params[:id]) unless @blog
    unless @blog
      raise ActionController::RoutingError.new('Not Found')
    end
    @blogger = @blog.user
  end

  def index
    @blogs = Blog.published
  end

  def set_blogs_active_section
    @active_section = "about"
  end

end