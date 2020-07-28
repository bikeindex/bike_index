# We have a lot of custom forms
# We don't actually want rails to wrap the fields in a "field_with_errors" div, it breaks forms like the organized form
# Solution from https://rubyplus.com/articles/3401-Customize-Field-Error-in-Rails-5
ActionView::Base.field_error_proc = proc do |html_tag, _instance_tag|
  html_tag
end
