# This class is meant as a global cache for all WMS requests
class CapabilitiesCache
    constructor: () ->
        @callbacks = {}
        @responses = {}

    startRequest: (url) ->
        d3.xml "#{url}?service=wms&request=getCapabilities", 'application/xml', (error, response) =>
            if not error
                @responses[url] = {
                  layers: {},
                  document: response
                }
                for internalCallback in @callbacks[url]
                    internalCallback(response)

    parseLayer: (url, layerName) ->
        console.log "parsing layer " + layerName + " of " + url
        doc = d3.select(@responses[url].document)
        for e in doc.selectAll('Layer > Dimension[name="time"]')[0]
            if layerName == d3.select(e.parentNode).select('Name').text()
                return d3.select(e).text().split(',').map (item) ->
                    record = item.split("/").slice(0, 2).map (time) ->
                        return new Date(time)
                    record.push({})
                    return record

    getLayer: (url, layerName) ->
        response = @responses[url]
        if not response.layers[layerName]?
            response.layers[layerName] = @parseLayer(url, layerName)

        return response.layers[layerName]


    addCallback: (url, layerName, callback) ->
        internalCallback = (response) =>
            callback(@getLayer(url, layerName))

        if @callbacks[url]?
            @callbacks[url].push internalCallback
        else
            @callbacks[url] = [internalCallback]
            @startRequest(url)


    # this is the main method to use to get the layer description
    get: (url, layerName, callback) ->
        if @responses[url]?
            callback(@getLayer(url, layerName))
        else
            @addCallback(url, layerName, callback)

cache = new CapabilitiesCache


class WMSSource
    constructor: (@options) ->

    fetch: (start, end, params, callback) ->
        cache.get @options.url, @options.layer, (layer) =>
            callback(layer)


module.exports = WMSSource
