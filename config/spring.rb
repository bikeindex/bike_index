require "spring/application"

class Spring::Application
  alias connect_database_orig connect_database

  # Disconnect & reconfigure to pickup DB name with
  # TEST_ENV_NUMBER suffix
  def connect_database
    disconnect_database
    reconfigure_database
    connect_database_orig
  end

  # Here we simply replace existing AR from main spring process
  def reconfigure_database
    if active_record_configured?
      ActiveRecord::Base.configurations =
        Rails.application.config.database_configuration
    end
  end
end
