=begin
*****************************************************************
* File: app/controllers/mailer_integrations_controller.rb 
* Name: Class MailerIntegrationsController 
* Paged index and show of mailer integrations
*****************************************************************
=end

class MailerIntegrationsController < ApplicationController

  def show
    template_config = MailerIntegration.new.template_config(params[:id])
    render template_config['name'], layout: false
  end

  def index
    @showSubstitutionValues = params[:showSubstitutionValues]
    render layout: 'application_updated'
  end
end
