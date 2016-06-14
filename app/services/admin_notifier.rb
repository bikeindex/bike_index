class AdminNotifier
  def for_organization(organization:, user:, type:)
    feedback = Feedback.new(email: user.email,
      feedback_hash: { organization_id: organization.id })
    if type == 'organization_created'
      feedback.body = "#{organization.name} created an account"
      feedback.title = "New Organization created"
      feedback.feedback_type = 'organization_created'
    elsif type == 'organization_destroyed'
      feedback.body = "#{organization.name} deleted their account"
      feedback.title = "Organization deleted themselves"
      feedback.feedback_type = 'organization_destroyed'
    else
      feedback.feedback_type = 'organization_map'
      if type == 'wants_shown'
        feedback.body = "#{organization.name} wants to be shown"
        feedback.title = "Organization wants to be shown"
      else
        feedback.body = "#{organization.name} wants to NOT be shown"
        feedback.title = "Organization wants OFF map"
      end
    end
    raise StandardError, "Couldn't notify admins" unless feedback.save
  end
end