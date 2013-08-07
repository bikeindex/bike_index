# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Bikeindex::Application.initialize!

Haml::Template.options[:ugly] = true