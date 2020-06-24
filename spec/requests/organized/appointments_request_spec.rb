require "rails_helper"

RSpec.describe Organized::AppointmentsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/appointments" }

end
