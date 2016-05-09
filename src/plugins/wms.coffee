class window.TimeSlider.Plugin.WMS
    constructor: (@options = {})->
        callback = (start, end, callback) =>
            @data = JSON.parse(localStorage.getItem(@options.url)) if JSON?
            unless @data?
                d3.xml("#{@options.url}?service=wms&request=getCapabilities", 'application/xml', (error, response) =>
                    @data = {
                        layers: {},
                        reloaded_at: null
                    } unless @data?
                    if not error
                        @data.reloaded_at = new Date()
                        r = d3.select(response)
                        for e in r.selectAll('Layer > Dimension[name="time"]')[0]
                            layer = d3.select(e.parentNode).select('Name').text()
                            dates = d3.select(e).text().split(',')
                            @data.layers[layer] = dates

                        localStorage.setItem(@options.url, JSON.stringify(@data)) if JSON?
                        callback(@options.dataset, @data.layers[@options.eoid])
                )
            else
                callback(@options.dataset, @data.layers[@options.eoid])

        return callback
