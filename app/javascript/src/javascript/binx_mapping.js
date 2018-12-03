import * as log from "loglevel";
if (process.env.NODE_ENV != "production") log.setLevel("debug");
import _ from "lodash";

window.BinxMapping = class BinxMapping {
  // The page instance of this class is modified to store the current list of points for rendering
  constructor(kind) {
    this.kind = kind;
    this.searchBox = null;
    this.searchMarkers = [];
    this.markerPointsToRender = [];
    this.markersRendered = [];
  }

  loadMap(callback) {
    if (window.googleMapInjected || this.googleMapsLoaded()) {
      return true;
    }
    // Add google maps script
    var js_file = document.createElement("script");
    js_file.type = "text/javascript";
    js_file.src = `https://maps.googleapis.com/maps/api/js?callback=${callback}&key=${
      window.pageInfo.google_maps_key
    }&libraries=places`;
    document.getElementsByTagName("head")[0].appendChild(js_file);
    window.googleMapInjected = true;
  }

  render(lat, lng, zoom = null) {
    if (zoom == null) {
      zoom = 13;
    }
    binxMapping.zoom = zoom;
    var myOptions = {
      zoom: zoom,
      center: new google.maps.LatLng(lat, lng),
      gestureHandling: "cooperative",
      mapTypeId: google.maps.MapTypeId.ROADMAP
    };
    if (!window.infoWindow) {
      window.infoWindow = new google.maps.InfoWindow();
    }
    window.binxMap = new google.maps.Map(
      document.getElementById("map"),
      myOptions
    );
  }

  googleMapsLoaded() {
    return typeof google === "object" && typeof google.maps === "object";
  }

  fitMap() {
    let bounds = new google.maps.LatLngBounds();
    // Fit to markers
    for (let marker of Array.from(binxMapping.markersRendered)) {
      if (marker) {
        bounds.extend(marker.getPosition());
      }
    }
    binxMap.fitBounds(bounds);

    // Finish rendering map, then check - if too zoomed in (e.g. on one point), zoom out
    window.setTimeout(function() {
      if (binxMap.zoom > 16) {
        binxMap.setZoom(16);
      }
    }, 500);
  }

  renderAddressSearch() {
    if (binxMapping.searchBox != null) {
      return true;
    }
    $("#map").before(
      '<input id="placeSearch" class="controls form-control" type="text" placeholder="Search map">'
    );
    let input = document.getElementById("placeSearch");
    binxMapping.searchBox = new google.maps.places.SearchBox(input);
    window.binxMap.controls[google.maps.ControlPosition.TOP_RIGHT].push(input);
    // Bias SearchBox results towards current map's viewport.
    binxMap.addListener("bounds_changed", () =>
      binxMapping.searchBox.setBounds(binxMap.getBounds())
    );

    binxMapping.searchBox.addListener("places_changed", function() {
      let places = binxMapping.searchBox.getPlaces();
      if (places.length === 0) {
        log.debug("Unable to find that address");
      }
      // For each place, get the icon, name and location.
      let bounds = new google.maps.LatLngBounds();
      places.forEach(function(place) {
        if (!place.geometry) {
          log.debug("Returned place contains no geometry");
        }
        // Create a marker for each place
        binxMapping.searchMarkers.push(
          new google.maps.Marker({
            map: binxMap,
            icon:
              "http://maps.google.com/mapfiles/ms/micons/purple-pushpin.png",
            title: place.name,
            position: place.geometry.location
          })
        );
        bounds.extend(place.geometry.location);
      });
      return binxMap.fitBounds(bounds);
    });

    // Record that the place search is rendered
    return (binxMapping.renderedAddressSearch = true);
  }

  clearMarkers() {
    if (!binxMapping.markersRendered) {
      binxMapping.markersRendered = [];
    }

    if (window.infoWindow != null) {
      window.infoWindow.close();
    }
    // Useful when the page reloads without fully reloading
    if (binxMapping.markersRendered.length) {
      for (let i of Array.from(binxMapping.markersRendered)) {
        i != null && i.setMap(null);
      }
    }
    // Ids make sure we aren't double rendering
    return (window.renderedMarkerIds = []);
  }

  markersInViewport() {
    let bounds = binxMap.getBounds();
    return _.filter(binxMapping.markersRendered, function(m) {
      return bounds.contains(m.getPosition());
    });
  }

  renderMarker(point) {
    let popupContent = "";
    if (binxMapping.kind == "geolocated_messages") {
      popupContent = binxAppOrgMessages.geolocatedMessageMapPopup(point);
    } else {
      log.debug(binxMapping.kind);
      popupContent = "Missing template!";
    }
    window.infoWindow.setContent(popupContent);
    // Ensure things are rendered before setting times, pause for a hot sec
    window.setTimeout(() => binxApp.localizeTimes(), 50);
  }

  openInfoWindow(marker, markerId, point) {
    window.infoWindow.setContent("");
    window.infoWindow.open(window.binxMap, marker);
    binxMapping.enableEscapeForInfoWindows();
    // For an unclear reason, this needs to return the rendered marker
    return binxMapping.renderMarker(point);
  }

  enableEscapeForInfoWindows() {
    // Enable using escape key to close info windows
    // Make sure we aren't adding duplicate handlers, sometimes we don't catch the close event
    $(window).off("keyup");
    // Add the trigger for the escape closing the window
    $(window).on("keyup", function(e) {
      if (e.keyCode === 27) {
        window.infoWindow.close();
        // Escape was pressed, infoWindow is closed, so remove the keyup handler
        $(window).off("keyup");
      }
      return true; // allow bubbling up
    });
    // on infowindow close, remove keyup handler - aka clean up after yourself
    google.maps.event.addListener(window.infoWindow, "closeclick", function() {
      $(window).off("keyup");
    });
  }

  addMarkers({ fitMap = false, renderAddressSearch = true }) {
    log.debug(`adding markers - fitMap: ${fitMap}`);
    while (binxMapping.markerPointsToRender.length > 0) {
      let point = binxMapping.markerPointsToRender.shift();
      let markerId = point.id;
      if (_.find(binxMapping.markersRendered, ["id", point.id])) {
        log.debug(`already rendered point: ${point.id}`);
      } else {
        let marker = new google.maps.Marker({
          position: new google.maps.LatLng(point.lat, point.lng),
          map: window.binxMap,
          binxId: markerId
        });

        google.maps.event.addListener(
          marker,
          "click",
          ((marker, markerId) =>
            function() {
              return binxMapping.openInfoWindow(marker, markerId, point);
            })(marker, markerId)
        );
        binxMapping.markersRendered.push(marker);
      }
    }
    // If we're suppose to fit the map to the markers - and if there are markers that have been rendered - fit it
    if (fitMap == true && binxMapping.markersRendered.length > 0) {
      binxMapping.fitMap();
    }
    // If we're suppose to include the address search, do it
    if (renderAddressSearch == true) {
      binxMapping.renderAddressSearch();
    }
  }
};
