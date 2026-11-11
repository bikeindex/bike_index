class RenameEducationCourseTemplateIndexes < ActiveRecord::Migration[8.1]
  def change
    rename_index :education_courses, "index_education_courses_one_active_template", "index_education_courses_one_active_default"
    rename_index :education_courses, "index_education_courses_one_draft_template", "index_education_courses_one_draft_default"
  end
end
