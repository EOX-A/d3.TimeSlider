class TimeSlider.Plugin.EOWCS
    constructor: (@options = {})->

        @formatDate = (date) ->
            date = date.toISOString()
            date = date.substring(0, date.length - 5)
            date + "Z"

        callback = (start, end, callback) =>
            request = d3.xhr(WCS.EO.KVP.describeEOCoverageSetURL(@options.url, @options.eoid, { subsetTime: [ @formatDate(start), @formatDate(end) ] }))
            request.get( (error, response) =>
                return [] if error

                datasets = []
                response = WCS.Core.Parse.parse(response.responseXML)
                for coverage in response.coverageDescriptions
                    datasets.push([ new Date(coverage.timePeriod[0]), new Date(coverage.timePeriod[1]) ])

                callback(@options.dataset, datasets)
            )

        return callback
