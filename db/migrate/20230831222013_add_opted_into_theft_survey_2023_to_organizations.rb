class AddOptedIntoTheftSurvey2023ToOrganizations < ActiveRecord::Migration[6.1]
  def change
    add_column :organizations, :opted_into_theft_survey_2023, :boolean, default: false
    add_column :users, :no_non_theft_notification, :boolean, default: false
  end
end
