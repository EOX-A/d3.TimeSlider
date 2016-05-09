
class WMSSource
    constructor: (@options) ->
        @layers = null
        @callbacks = []

    fetch: (start, end, params, callback) ->
        if not @layers
            @callbacks.push([callback, layerName])
            d3.xml "#{@options.url}?service=wms&request=getCapabilities", 'application/xml', (error, response) =>
                if not error
                    @r = d3.select(response)
                    for [callback, layerName] of @callbacks
                        callback(@getLayer(params.layerName))
                    @callbacks = null
        else
            callback(@getLayer(params.layerName))

    getLayer: (layerName) ->
        if not @layers
            @layers = {}

        if not @layers[layerName]
            @layers[layerName] = parseLayer(layerName)

        return @layers[layerName]

    parseLayer: (layerName) ->
        for e in @r.selectAll('Layer > Dimension[name="time"]')[0]
            if @options.layer == d3.select(e.parentNode).select('Name').text()
                return d3.select(e).text().split(',')


module.exports = WMSSource