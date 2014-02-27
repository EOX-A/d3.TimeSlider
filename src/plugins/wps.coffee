class TimeSlider.Plugin.WPS
    
    constructor: (@options = {})->

        @formatDate = (date) ->
            # All EO-WCS servers used for testing can't handle subsecond precision dates, so we strip this information
            date.toISOString().substring(0, 19) + "Z"

        @current_bbox = @options.bbox
        @current_data = null
        @current_start = new Date();
        @current_end = new Date();

        callback = (start, end, callback, bbox) =>
           
            if (@current_start.getTime() != start.getTime() && @current_end.getTime() != end.getTime())
                #console.log "Fetching data for " + @options.eoid 
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
                        inside = false
                        if !@current_bbox
                            inside = true
                        else 
                            bbox_a = coverage.bbox.replace(/[()]/g,'').split(',').map(parseFloat)
                            if(!(@current_bbox[0] > bbox_a[2] || @current_bbox[2] < bbox_a[0] || @current_bbox[3] < bbox_a[1] || @current_bbox[1] > bbox_a[3]) )
                                inside = true

                        datasets.push([ new Date(coverage.starttime), new Date(coverage.endtime), coverage.identifier, coverage.bbox, inside ])

                    @current_data = datasets
                    @current_bbox = bbox
                    @current_start = start
                    @current_end = end

                    callback(@options.dataset, datasets)
                )

            else
                #console.log "Updating data for " + @options.eoid 
                datasets = []
                for coverage in @current_data
                    inside = false
                    bbox_a = coverage[3].replace(/[()]/g,'').split(',').map(parseFloat)
                    if @current_bbox
                        if(!(bbox[0] > bbox_a[2] || bbox[2] < bbox_a[0] || bbox[3] < bbox_a[1] || bbox[1] > bbox_a[3]) )
                            inside = true
                    else
                        inside = true

                    datasets.push([ new Date(coverage[0]), new Date(coverage[1]), coverage[2], coverage[3], inside ])

                @current_data = datasets
                @current_bbox = bbox

                callback(@options.dataset, datasets)

        return callback
