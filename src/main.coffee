# this file is the entry-point for the browserify bundler and exports the global
# TimeSlider variable
window.TimeSlider = require "./d3.timeslider.coffee"

window.TimeSlider.Sources = {
    EOWCSSource: require("./sources/eowcs.coffee")
    EOxServerWPSSource: require("./sources/eoxserver-wps.coffee")
    WMSSource: require("./sources/wms.coffee")
}