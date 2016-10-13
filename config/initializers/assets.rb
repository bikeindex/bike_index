# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.2'

Rails.application.config.assets.precompile += %w(
  graphs.js embed.js embed_user.js documentation_v2.js documentation_v3.js 
  application_revised.js registrations.js
  spokecard.css embed_styles.css embed_user_styles.css registration_pdf.css
  updated_styles.css documentation_v2.css revised.css og_application.css
  registrations.css email.css
)
