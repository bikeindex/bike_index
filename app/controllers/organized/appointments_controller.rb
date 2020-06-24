module Organized
  class AppointmentsController < Organized::AdminController
    before_action :find_appointment, except: [:create]

    def show; end

    def update
    end

    def create
    end

    private

    def find_appointment
    end

    def permitted_parameters
      params.require(:appointment).permit()
    end
  end
end
