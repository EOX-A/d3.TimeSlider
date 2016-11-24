class EOxServerWPSSource
    constructor: (@options = {}) ->

    formatDate: (date) ->
        # All EO-WCS servers used for testing can't handle subsecond precision
        # dates, so we strip this information
        date.toISOString().substring(0, 19) + "Z"

    fetch: (start, end, params, callback) ->
        d3.csv "#{@options.url}?service=wps&request=execute&version=1.0.0&identifier=getTimeData&DataInputs=collection=#{@options.eoid}%3Bbegin_time=#{@formatDate(start)}%3Bend_time=#{@formatDate(end)}&RawDataOutput=times"
            .row (row) => [
                new Date(row.starttime),
                new Date(row.endtime), {
                    id: row.identifier,
                    bbox: row.bbox.replace(/[()]/g,'').split(',').map(parseFloat)
                }
            ]
            .get (error, rows) =>
                if not error
                    callback(rows)

module.exports = EOxServerWPSSource
