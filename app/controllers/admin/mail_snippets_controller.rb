class Admin::MailSnippetsController < Admin::BaseController
  before_filter :find_snippet, except: [:index, :new, :create]
  
  def index
    @mail_snippets = MailSnippet.all
  end

  def show
    redirect_to edit_admin_mail_snippet_url(@mail_snippet)
  end

  def edit
    
  end

  def update
    if @mail_snippet.update_attributes(permitted_parameters)
      flash[:success] = 'Snippet Saved!'
      redirect_to edit_admin_mail_snippet_url(@mail_snippet)
    else
      render action: :edit
    end
  end

  def new
    @mail_snippet = MailSnippet.new
  end

  def create
    @mail_snippet = MailSnippet.create(permitted_parameters)
    if @mail_snippet.save
      flash[:success] = 'Snippet Created!'
      redirect_to edit_admin_mail_snippet_url(@mail_snippet)
    else
      render action: :new
    end
  end


  protected

  def permitted_parameters
    params.require(:mail_snippet).permit(MailSnippet.old_attr_accessible)
  end

  def find_snippet
    @mail_snippet = MailSnippet.find(params[:id])
  end
end
