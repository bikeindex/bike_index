# This file initializes js for the application
# All of the classes in the

class window.BikeIndex
  initialize: ->
    body_id = document.getElementsByTagName('body')[0].id

    new @pageClasses[body_id]



$(document).ready ->
  bike_index = new window.BikeIndex
  bike_index.initialize()
