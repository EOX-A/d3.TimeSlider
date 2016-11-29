parse = require("libcoverage/src/parse")

kvp = require("libcoverage/src/eowcs/kvp")
eoParse = require("libcoverage/src/eowcs/parse")


parse.pushParseFunctions(eoParse.parseFunctions)


class EOWCSSource
    constructor: (@options = {}) ->

    formatDate: (date) ->
        # All EO-WCS servers used for testing can't handle subsecond precision 
        # dates, so we strip this information
        date.toISOString().substring(0, 19) + "Z"

    fetch: (start, end, params, callback) ->
        url = kvp.describeEOCoverageSetURL(
            @options.url, params?.eoid or @options.eoid, {
                subsetTime: [
                    @formatDate(start), @formatDate(end)
                ]
            }
        )

        request = d3.xhr(url)
        request.get (error, response) =>
            if error
                return callback([])

            try
                response = parse.parse(response.responseXML, {throwOnException: true})
            catch
                return callback([])

            records = []
            if response.coverageDescriptions? and response.coverageDescriptions.length > 0
                for coverage in response.coverageDescriptions
                    bbox = [NaN, NaN, NaN, NaN]
                    footprint = []
                    for i in [0...coverage.footprint.length] by 2
                        [lon, lat] = [coverage.footprint[i+1], coverage.footprint[i]]
                        footprint.push([lon, lat])
                        bbox[0] = if isNaN(bbox[0]) then lon  else Math.min(lon, bbox[0])
                        bbox[1] = if isNaN(bbox[1]) then lat  else Math.min(lat, bbox[1])
                        bbox[2] = if isNaN(bbox[2]) then lon  else Math.max(lon, bbox[2])
                        bbox[3] = if isNaN(bbox[3]) then lat  else Math.max(lat, bbox[3])

                    records.push([
                        new Date(coverage.timePeriod[0]),
                        new Date(coverage.timePeriod[1]), {
                            id: coverage.coverageId,
                            bbox: bbox,
                            footprint: footprint
                        }
                    ])

            callback(records)

module.exports = EOWCSSource