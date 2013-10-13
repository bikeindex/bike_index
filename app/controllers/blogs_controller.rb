class BlogsController < ApplicationController
  layout 'content'
  before_filter :set_blogs_active_section

  def show
    @blog = Blog.find_by_title_slug(params[:id])
    unless @blog
      raise ActionController::RoutingError.new('Not Found')
    end
    @blogger = @blog.user
    @title = @blog.title
  end

  def index
    @title = "Blog"
    @blogs = Blog.where(published: true)
  end

  def set_blogs_active_section
    @active_section = "about"
  end

end