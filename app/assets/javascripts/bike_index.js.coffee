window.BikeIndex =
  Models: {}
  Collections: {}
  Views: {}
  Routers: {}
  init: ->

  hideFlash: () ->
    # Fade out hovering alerts after 10 seconds
    setTimeout("$('#alert-block').fadeOut('slow')", 10000)

  alertMessage: (type, title, message) ->
    $('#alert-block>div').addClass("hidden")
    $('#alert-block').css('display', 'block')
    $('#alert-block').append("""
        <div class="alert-#{type}" data-alert="alert">
          <a class="close" data-dismiss="alert" href="#">×</a>
          <h4>#{title}</h4>
          <div class="padded">#{message}</div>
        </div>
      """)
    BikeIndex.hideFlash()
    links = links + "</ul></div>"

    # $('#total-top-header .global-tabs').append(tab)
    # $('#total-top-header .tab-content').append(links)

$(document).ready ->
  new BikeIndex.Views.Global

  if document.getElementById('home_headies')
    new BikeIndex.Views.Home 
  if document.getElementById('news_display')
    new BikeIndex.Views.NewsDisplay 

  else if document.getElementById('documentation-menu')
    new BikeIndex.Views.DocumentationIndex

  else if document.getElementById('content-wrap')
    if document.getElementById('where-bike-index')
      new BikeIndex.Views.ContentWhere
    if document.getElementById('manufacturers-list')
      new BikeIndex.Views.ContentManufacturers
  
  if document.getElementById('stripe_form')
    new BikeIndex.Views.PaymentsForm

  else if document.getElementById('choose-registration-type')
    new BikeIndex.Views.BikesChooseRegistration

  else if document.getElementById('bikes-search')
    new BikeIndex.Views.BikesSearch

  else if document.getElementById('bike-show')
    new BikeIndex.Views.BikesShow

  else if document.getElementById('photos-flip')
    new BikeIndex.Views.LoginSignup

  else if document.getElementById('organization-content')
    new BikeIndex.Views.OrganizationsShow

  else if document.getElementById('user-home-page')
    new BikeIndex.Views.DataTables
  
  else if document.getElementById('edit-bike-form')
    new BikeIndex.Views.BikesEdit

  else if document.getElementById('edit-user-form')
    new BikeIndex.Views.UsersEdit

  else if document.getElementById('lock-form')
    new BikeIndex.Views.LocksForm

  else if document.getElementById('new_bike')
    new BikeIndex.Views.BikesNew

  else if document.getElementById('admin-content')
    new BikeIndex.Views.DataTables
    if document.getElementById('bike_edit_root_url')
      new BikeIndex.Views.AdminBikesEdit
    else if document.getElementById('admin-locations-fields')
      new BikeIndex.Views.AdminOrganizationsEdit
    else if document.getElementById('admin-recoveries')
      new BikeIndex.Views.AdminRecoveries
    else if document.getElementById('blog-edit')
      new BikeIndex.Views.AdminBlogsEdit
    else if document.getElementById('graph-holder')
      new BikeIndex.Views.AdminGraphs
  
  else if document.getElementById('photo-page')
    new BikeIndex.Views.PhotosIndex

  if document.getElementById('multi_serial_search')
    new BikeIndex.Views.StolenMultiSerialSearch
    
