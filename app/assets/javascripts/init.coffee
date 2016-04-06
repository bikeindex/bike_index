# This file initializes scripts for the application

class window.BikeIndex
  pageClasses:
    info_about: BikeIndex.InfoAbout

  pageLoad: ->
    new BikeIndex.NavHeader
    body_id = document.getElementsByTagName('body')[0].id
    new @pageClasses[body_id] if @pageClasses[body_id]




$(document).ready ->
  bike_index = new window.BikeIndex
  bike_index.pageLoad()
