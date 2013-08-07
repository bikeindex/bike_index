class BikeIndex.Views.AdminBlogsEdit extends Backbone.View
    
  initialize: ->
    $('#post-date-field input').datepicker('format: mm-dd-yyy')
    
    