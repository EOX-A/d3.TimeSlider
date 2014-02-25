class TimeSlider.Plugin.WPS
    constructor: (@options = {})->

        @formatDate = (date) ->
            # All EO-WCS servers used for testing can't handle subsecond precision dates, so we strip this information
            date.toISOString().substring(0, 19) + "Z"

        callback = (start, end, callback) =>
            postdata = """
                <?xml version="1.0" encoding="UTF-8"?>
                <wps:Execute version="1.0.0" service="WPS" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.opengis.net/wps/1.0.0" xmlns:wfs="http://www.opengis.net/wfs" xmlns:wps="http://www.opengis.net/wps/1.0.0" xmlns:ows="http://www.opengis.net/ows/1.1" xmlns:gml="http://www.opengis.net/gml" xmlns:ogc="http://www.opengis.net/ogc" xmlns:wcs="http://www.opengis.net/wcs/1.1.1" xmlns:xlink="http://www.w3.org/1999/xlink" xsi:schemaLocation="http://www.opengis.net/wps/1.0.0 http://schemas.opengis.net/wps/1.0.0/wpsAll.xsd">
                  <ows:Identifier>getTimeData</ows:Identifier>
                  <wps:DataInputs>
                    <wps:Input>
                      <ows:Identifier>collection</ows:Identifier>
                      <wps:Data>
                        <wps:LiteralData>#{ @options.eoid }</wps:LiteralData>
                      </wps:Data>
                    </wps:Input>
                    <wps:Input>
                      <ows:Identifier>begin_time</ows:Identifier>
                      <wps:Data>
                        <wps:LiteralData>#{ @formatDate(start) }</wps:LiteralData>
                      </wps:Data>
                    </wps:Input>
                    <wps:Input>
                      <ows:Identifier>end_time</ows:Identifier>
                      <wps:Data>
                        <wps:LiteralData>#{ @formatDate(end) }</wps:LiteralData>
                      </wps:Data>
                    </wps:Input>
                  </wps:DataInputs>
                  <wps:ResponseForm>
                    <wps:RawDataOutput mimeType="text/plain">
                      <ows:Identifier>times</ows:Identifier>
                    </wps:RawDataOutput>
                  </wps:ResponseForm>
                </wps:Execute>
            """
            request = d3.csv(@options.url)

            request.post(postdata, (error, response) =>
                callback(@options.dataset, []) if error

                datasets = []

                for coverage in response
                    datasets.push([ new Date(coverage.starttime), new Date(coverage.endtime) ])

                callback(@options.dataset, datasets)
            )

        return callback


