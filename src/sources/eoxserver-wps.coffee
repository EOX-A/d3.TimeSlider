class EOxServerWPSSource
    constructor: (@options = {}) ->

    formatDate: (date) ->
        # All EO-WCS servers used for testing can't handle subsecond precision
        # dates, so we strip this information
        date.toISOString().substring(0, 19) + "Z"

    fetch: (start, end, params, callback) ->
        # TODO: Start and end time inputs
        requestString = "#{@options.url}?service=wps&request=execute&version=1.0.0&identifier=getTimeData&DataInputs=collection=#{@options.eoid}&RawDataOutput=times"

        request = d3.csv requesString
        request.row (row) => [
            new Date(row.starttime),
            new Date(row.endtime), {
                id: row.identifier,
                bbox: row.bbox.replace(/[()]/g,'').split(',').map(parseFloat)
            }
        ]
        request.get (error, rows) =>
            if not error
                callback(rows)

module.exports = EOxServerWPSSource
