# Preview emails at http://localhost:3000/rails/mailers/organized_mailer
class OrganizedMailerPreview < ActionMailer::Preview
  def partial_registration
    b_param = BParam.last
    OrganizedMailer.partial_registration_email(b_param)
  end

  
end
