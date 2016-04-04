# This file initializes js for the application
# All of the classes in the

class window.BikeIndex
  pageClasses:
    info_about: BikeIndex.InfoAbout

  initialize: ->
    body_id = document.getElementsByTagName('body')[0].id
    console.log 'party here'
    console.log @pageClasses
    new @pageClasses[body_id]



$(document).ready ->
  bike_index = new window.BikeIndex
  bike_index.initialize()
