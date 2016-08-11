class Admin::MailerPreviewsController < Admin::BaseController
  def index
    @show_substitution_values = params[:show_substitution_values]
  end

  def show
    render layout: false
  end
end
