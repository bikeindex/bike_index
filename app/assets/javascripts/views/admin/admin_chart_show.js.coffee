class BikeIndex.Views.AdminChartShow extends Backbone.View
    
  initialize: ->
    @initialize_graph()



  initialize_graph: ->
    data_values1 = $('#graphy').data('values1')
    data_values2 = $('#graphy').data('values2')
    data_labels = $('#graphy').data('labels')
    options =
      bezierCurve: false
      scaleShowGridLines: false
      scaleOverlay : true
      # scaleOverride: true
      # scaleSteps: 2
      

    data =
      labels: data_labels
      datasets: [
        fillColor: "rgba(220,220,220,0.5)"
        strokeColor: "rgba(220,220,220,1)"
        pointColor: "rgba(220,220,220,1)"
        pointStrokeColor: "#fff"
        data: data_values1
      ,
        fillColor: "rgba(151,187,205,0.5)"
        strokeColor: "rgba(151,187,205,1)"
        pointColor: "rgba(151,187,205,1)"
        pointStrokeColor: "#fff"
        data: data_values2
      ]

    ctx = document.getElementById("graphy").getContext("2d")
    new Chart(ctx).Line data, options
    