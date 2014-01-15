window.BikeIndex =
  Models: {}
  Collections: {}
  Views: {}
  Routers: {}
  init: ->

  hideFlash:() ->
    # Fade out hovering alerts after 7 seconds
    setTimeout("$('#alert-block').fadeOut('slow')", 7000)

  alertMessage:(type, title, message) ->
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
    
    $('#total-top-header .global-tabs').append(tab)
    $('#total-top-header .tab-content').append(links)

  initializeHeaderSearch: ->
    $('#find_bike_attributes_ids').select2
      allow_single_deselect: true
      allowClear: true
      width: '100%'
    $("#head-search-bikes #query").attr("autocomplete","off");
    

$(document).ready ->
  view = new BikeIndex.Views.Global
  
  if $('#home-title').length > 0
    view = new BikeIndex.Views.Home 

  else if $('#documentation-menu').length > 0
    view = new BikeIndex.Views.DocumentationIndex

  else if $('#content-wrap').length > 0
    if $('#where-bike-index').length > 0
      view = new BikeIndex.Views.ContentWhere
    if $('#manufacturers-list').length > 0
      view = new BikeIndex.Views.ContentManufacturers

  else if $('#choose-registration-type').length > 0
    view = new BikeIndex.Views.BikesChooseRegistration

  else if $('#bikes-search').length > 0
    view = new BikeIndex.Views.BikesSearch

  else if $('#bike-show').length > 0
    view = new BikeIndex.Views.BikesShow

  else if $('#photos-flip').length > 0
    view = new BikeIndex.Views.LoginSignup

  else if $('#organization-content').length > 0
    view = new BikeIndex.Views.OrganizationsShow

  else if $('#user-bikes-table').length > 0
    view = new BikeIndex.Views.DataTables
  
  else if $('#edit-bike-form').length > 0
    view = new BikeIndex.Views.BikesEdit

  else if $('#edit-user-form').length > 0
    view = new BikeIndex.Views.UsersEdit

  else if $('#lock-form').length > 0
    view = new BikeIndex.Views.LocksForm

  else if $('#new_bike').length > 0
    view = new BikeIndex.Views.BikesNew

  else if $('#admin-content').length > 0
    view = new BikeIndex.Views.DataTables
    if $('#admin-locations-fields').length > 0
      view = new BikeIndex.Views.AdminOrganizationsEdit
    else if $('#post-date-field').length > 0
      view = new BikeIndex.Views.AdminBlogsEdit
    else if $('#graph-holder').length > 0
      view = new BikeIndex.Views.AdminChartShow
  
  else if $('#photo-page').length > 0
    view = new BikeIndex.Views.PhotosIndex
    
