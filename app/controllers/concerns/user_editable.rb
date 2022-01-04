# This is a concern because we need it for the users controller in addition to my_accounts
# TODO: make my_accounts update in my_accounts controller
module UserEditable
  extend ActiveSupport::Concern

  def edit_templates
    @edit_templates ||= {
      root: translation(:user_settings, scope: [:controllers, :my_accounts, :edit]),
      password: translation(:password, scope: [:controllers, :my_accounts, :edit]),
      sharing: translation(:sharing, scope: [:controllers, :my_accounts, :edit])
    }.as_json
  end

  def template_param
    params[:edit_template] || params[:page]
  end

  def assign_edit_template
    @edit_template = edit_templates[template_param].present? ? template_param : edit_templates.keys.first
  end
end
