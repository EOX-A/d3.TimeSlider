class TimeSlider.Plugin.EOWCS
    constructor: (@options = {})->

        @formatDate = (date) ->
            # All EO-WCS servers used for testing can't handle subsecond precision dates, so we strip this information
            date.toISOString().substring(0, 19) + "Z"

        callback = (start, end, callback) =>
            request = d3.xhr(WCS.EO.KVP.describeEOCoverageSetURL(@options.url, @options.eoid, { subsetTime: [ @formatDate(start), @formatDate(end) ] }))
            request.get( (error, response) =>
                callback(@options.dataset, []) if error

                datasets = []
                response = WCS.Core.Parse.parse(response.responseXML)
                for coverage in response.coverageDescriptions
                    datasets.push([ new Date(coverage.timePeriod[0]), new Date(coverage.timePeriod[1]) ])

                callback(@options.dataset, datasets)
            )

        return callback
