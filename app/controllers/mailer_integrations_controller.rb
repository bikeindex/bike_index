=begin
*****************************************************************
* File: app/controllers/mailer_integrations_controller.rb 
* Name: Class MailerIntegrationsController 
* Paged index and show of mailer integrations
*****************************************************************
=end

class MailerIntegrationsController < ApplicationController

=begin
  name: show
  Explication: show new template
  Params: MailerIntegration id
  Return: template
=end 
  def show
    template_config = MailerIntegration.new.template_config(params[:id])
    render template_config['name'], layout: false
  end

=begin
  name: index
  Explication:
  Params: showSubstitutionValues
  Return: layout
=end 
  def index
    @showSubstitutionValues = params[:showSubstitutionValues]
    render layout: 'application_updated'
  end
end
