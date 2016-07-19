class TimeSlider

    # TODO: Not sure if this is the only solution but this is needed to make sure
    #       events can be dispatched in Internet Explorer 11 (and below)
    `(function () {
      function CustomEvent ( event, params ) {
        params = params || { bubbles: false, cancelable: false, detail: undefined };
        var evt = document.createEvent( 'CustomEvent' );
        evt.initCustomEvent( event, params.bubbles, params.cancelable, params.detail );
        return evt;
       }

      CustomEvent.prototype = window.Event.prototype;

      window.CustomEvent = CustomEvent;
    })();`


    # TODO
    #  * Implement a function to fetch dataset information from a WMS / WCS service
    #  * Compute the padding at the left & right of the timeslider
    #  * TESTING

    constructor: (@element, @options = {}) ->
        # Debugging?
        @debug = false

        @brush_tooltip = true
        @brush_tooltip_offset = [-30, 20]

        @time_tooltip = true
        @time_tooltip_is_on = true
        @time_tooltip_offset = [-30, -35]

        @tooltip = d3.select("body").append("div")
            .attr("class", "tooltip")
            .style("opacity", 0)

        @tooltip_time = d3.select("body").append("div")
            .attr("class", "tooltip")
            .style("opacity", 0)

        @tooltip_brush_min = d3.select("body").append("div")
            .attr("class", "tooltip")
            .style("opacity", 0)
        @tooltip_brush_max = d3.select("body").append("div")
            .attr("class", "tooltip")
            .style("opacity", 0)

        #localStorage.clear()

        @bbox = null

        # create the root svg element
        @svg = d3.select(element).append('svg').attr('class', 'timeslider')

        @useBBox = false
        if(@svg[0][0].clientWidth == 0)
            d3.select(element).select('svg').append('rect').attr('width', '100%').attr('height', '100%').attr('opacity', '0')
            @useBBox = true

        # default options and other variables for later
        @options.width = if @useBBox then @svg[0][0].getBBox().width else @options.width  = @svg[0][0].clientWidth
        @options.height = if @useBBox then @svg[0][0].getBBox().height else @svg[0][0].clientHeight
        @options.brush ||= {}
        @options.brush.start ||= @options.start
        @options.brush.end ||= new Date(new Date(@options.brush.start).setDate(@options.brush.start.getDate() + 3))
        @options.debounce ||= 50
        @options.ticksize ||= 3
        @options.selectionLimit ||= -1
        @options.timeFormatStr ||= "%Y-%m-%d %H:%M:%S" # defaut time format used by the tooltips
        @options.timeTickDate ||= null
        @options.minBrushSize ||= 1.0 # minimum pixel size of the brush

        @brush_tooltip = @options.brushTooltip if @options.brushTooltip?
        @brush_tooltip_offset = @options.brushTooltipOffset if @options.brushTooltipOffset?

        @time_tooltip = @options.timeTooltip if @options.timeTooltip?
        @time_tooltip_offset = @options.timeTooltipOffset if @options.timeTooltipOffset?

        # array to hold individual data points / data ranges
        @data = {}

        @timeTickDate = @options.timeTickDate
        @timeFormat = d3.time.format.utc(@options.timeFormatStr)

        # debounce function for rate limiting
        @timeouts = []
        debounce = (timeout, id, fn) =>
            return unless timeout and id and fn
            @timeouts[id] = -1 unless @timeouts[id]

            return =>
                window.clearTimeout(@timeouts[id]) if @timeouts[id] > -1
                @timeouts[id] = window.setTimeout(fn, timeout)


        customFormats = d3.time.format.utc.multi([
            ["%S.%L", (d) -> d.getUTCMilliseconds() ]
            ["%M:%S", (d) -> d.getUTCSeconds() ],
            ["%H:%M", (d) -> d.getUTCMinutes() ],
            ["%H:%M", (d) -> d.getUTCHours() ],
            ["%b %d", (d) ->d.getUTCDay() && d.getUTCDate() != 1 ],
            ["%b %d", (d) -> d.getUTCDate() != 1 ],
            ["%b", (d) -> d.getUTCMonth() ],
            ["%Y", -> true ]
        ])

        # scales
        @scales =
            x: d3.time.scale.utc()
                .domain([ @options.domain.start, @options.domain.end ])
                .range([0, @options.width])
                .nice()
            y: d3.scale.linear()
                .range([@options.height-29, 0])

        # axis
        @axis =
            x: d3.svg.axis()
                .scale(@scales.x)
                .innerTickSize(@options.height - 15)
                .tickFormat(customFormats)
            y: d3.svg.axis()
                .scale(@scales.y)
                .orient("left")

        @svg.append('g')
            .attr('class', 'mainaxis')
            .call(@axis.x)

        # translate the main x axis
        d3.select(@element).select('g.mainaxis .domain')
            .attr('transform', "translate(0, #{options.height - 18})")


        # brush
        @brushExtent = [@options.brush.start, @options.brush.end]

        @redrawBrush = (extent)->
            @brushExtent = extent if extent?
            # make sure the selection does not disapper when we zoom out
            extent = @brushExtent
            pixext = [@scales.x(extent[0]), @scales.x(extent[1])]
            size = @options.minBrushSize
            if (pixext[1] - pixext[0]) < size
                mean = 0.5 * (pixext[1] + pixext[0])
                extent = [
                    @scales.x.invert(mean - 0.5 * size),
                    @scales.x.invert(mean + 0.5 * size)
                ]
            @brush.x(@scales.x).extent(extent)
            d3.select(@element).select('g.brush').call(@brush)

        @brush = d3.svg.brush()
            .x(@scales.x)
            .on('brushstart', =>
                @time_tooltip_is_on = false
                @options.lastZoom = {
                    scale: @options.zoom.scale(),
                    translate: [
                        @options.zoom.translate()[0],
                        @options.zoom.translate()[1],
                    ]
                }

                @options.zoom.on('zoom', null)
            )
            .on('brushend', =>
                @time_tooltip_is_on = true
                @options.zoom
                    .scale(@options.lastZoom.scale)
                    .translate(@options.lastZoom.translate)
                    .on('zoom', @redraw)

                extent = @brush.extent()

                # Check for selection limit and reduce to correct size
                if(@options.selectionLimit > 0)
                    @svg.selectAll('.brush')
                        .attr({fill: "#333"})
                    if (extent[1] - extent[0])/1000 >= @options.selectionLimit
                        extent = [extent[0], new Date(
                            extent[0].getTime() + @options.selectionLimit*1000
                        )]
                        @brush.extent(extent)
                        d3.select(@element).select('g.brush').call(@brush)

                @brushExtent = extent

                @element.dispatchEvent(
                    new CustomEvent('selectionChanged', {
                        detail: {start: extent[0], end: extent[1]}
                        bubbles: true,
                        cancelable: true
                    })
                )

                if (@brush_tooltip)
                    @tooltip_brush_min.transition()
                        .duration(100)
                        .style("opacity", 0)

                    @tooltip_brush_max.transition()
                        .duration(100)
                        .style("opacity", 0)

            )
            .on('brush', =>
                @options.zoom
                    .scale(@options.lastZoom.scale)
                    .translate(@options.lastZoom.translate)
                extent = @brush.extent()

                # Check for selection limit, warn in red if selection is to big
                if @options.selectionLimit > 0
                    if (extent[1] - extent[0])/1000 > @options.selectionLimit
                        @svg.selectAll('.brush')
                            .attr({fill: "red"})
                    else
                        @svg.selectAll('.brush')
                            .attr('class', 'brush brush-ok')
                            .attr({fill: "#333"})

                if @brush_tooltip
                    offheight = 0
                    node = @svg[0][0]

                    if node.parentElement?
                        height = node.parentElement.offsetHeight
                    else
                        height = node.parentNode.offsetHeight

                    node_offset = node.getBoundingClientRect()
                    offset_x = @brush_tooltip_offset[0] + node_offset.left
                    offset_y = @brush_tooltip_offset[1] + node_offset.top

                    @tooltip_brush_min.transition()
                        .duration(100)
                        .style("opacity", .9)
                    @tooltip_brush_min.html(@timeFormat(extent[0]))
                        .style("left", (@scales.x(extent[0]) + offset_x) + "px")
                        .style("top", offset_y + "px")

                    @tooltip_brush_max.transition()
                        .duration(100)
                        .style("opacity", .9)
                    @tooltip_brush_max.html(@timeFormat(extent[1]))
                        .style("left", (@scales.x(extent[1]) + offset_x) + "px")
                        .style("top", (offset_y + 20) + "px")

            )

        @svg.append('g')
            .attr('class', 'brush')
            .call(@brush)
            .selectAll('rect')
                .attr('height', "#{@options.height - 19}")
                .attr('y', 0)

        # datasets
        @svg.append('g')
            .attr('class', 'datasets')
            .attr('width', @options.width)
            .attr('height', @options.height)
            .attr('transform', "translate(0, #{options.height - 23})")

        @drawDataset = (dataset) =>

            @options.datasetIndex = 0 unless @options.datasetIndex?
            @options.linegraphIndex = 0 unless @options.linegraphIndex?

            index = @options.datasetIndex
            lineplot = false

            if !dataset.lineplot
                index = @options.datasetIndex++
                @svg.select('g.datasets')
                    .insert('g',':first-child')
                        .attr('class', 'dataset')
                        .attr('id', "dataset-#{dataset.id}")
            else
                index = @options.linegraphIndex++
                lineplot = true
                @svg.select('g.datasets')
                    .append('g')
                        .attr('class', 'dataset')
                        .attr('id', "dataset-#{dataset.id}")


            @data[dataset.id] = {
                index: index,
                color: dataset.color,
                callback: dataset.data,
                points: [],
                ranges: [],
                lineplot: lineplot
            }

            @reloadDataset(dataset.id)

        @updateDataset = (dataset) =>

            el = @svg.select("g.datasets #dataset-#{dataset}")
            d = @data[dataset]

            points = d.ranges.filter((values) => (@scales.x(new Date(values[1])) - @scales.x(new Date(values[0]))) < 5)#.map((values) => values[0])
            ranges = d.ranges.filter((values) => (@scales.x(new Date(values[1])) - @scales.x(new Date(values[0]))) >= 5)

            if(d.paths && d.paths.length>0)
                drawPaths(el, d.paths, { index: d.index, color: d.color })
            else
                drawRanges(el, ranges, { index: d.index, color: d.color })
                drawPoints(el, points.concat(d.points), { index: d.index, color: d.color })


        @setTimetick = (date) =>
            @timeTickDate = date
            drawTimetick()


        drawTimetick = () =>
            @svg.selectAll('.timetick').remove()

            if (Object.prototype.toString.call(@timeTickDate) == '[object Date]')

                r = @svg.selectAll('.timetick')
                    .data([@timeTickDate])

                r.enter().append('rect')
                    .attr('class', 'timetick')
                    .attr('x', (a)=>  @scales.x(a) )
                    .attr('y', 0 )
                    .attr('width', (a)=>  1 )
                    .attr('height', (@options.height-20))
                    .attr('stroke', 'red')
                    .attr('stroke-width', 1)
                    .attr('fill', (a) =>  options.color)

                r.exit().remove()


        drawRanges = (element, data, options) =>

            element.selectAll('rect').remove()

            r = element.selectAll('rect')
                .data(data)

            r.enter().append('rect')
                .attr('x', (a) =>  @scales.x(new Date(a[0])) )
                .attr('y', - (@options.ticksize + 3) * options.index + -(@options.ticksize-2) )
                .attr('width', (a) =>  (@scales.x(new Date(a[1])) - @scales.x(new Date(a[0]))) )
                .attr('height', (@options.ticksize-2))
                .attr('stroke', d3.rgb(options.color).darker())
                .attr('stroke-width', 1)
                .attr('fill', (a) =>
                    if(a[4]==false)
                        "transparent"
                    else
                        options.color
                )
                .on("mouseover", (d) =>
                    if (d[2])
                        @time_tooltip_is_on = false
                        @tooltip.transition()
                            .duration(100)
                            .style("opacity", .9)
                        @tooltip.html(d[2])
                            .style("left", (d3.event.pageX) + "px")
                            .style("top", (d3.event.pageY - 28) + "px")
                )
                .on("mousemove", (d) =>
                    @tooltip
                        .style("left", (d3.event.pageX) + "px")
                        .style("top", (d3.event.pageY - 28) + "px")
                )
                .on("mouseout", (d) =>
                    @time_tooltip_is_on = true
                    @tooltip.transition()
                        .duration(100)
                        .style("opacity", 0)
                )
                .on('click', (d) =>
                    @element.dispatchEvent(
                        new CustomEvent('coverageselected', {
                            detail: {
                                id: d[2],
                                bbox: d[3],
                                start: d[0],
                                end:d[1]
                            }
                            bubbles: true,
                            cancelable: true
                        })
                    )
                )

            r.exit().remove()

        drawPoints = (element, data, options) =>
            element.selectAll('circle').remove()
            p = element.selectAll('circle')
               .data(data)

            p.enter().append('circle')
                .attr('cx', (a) =>
                    if Array.isArray(a)
                        return @scales.x(new Date(a[0]))
                    else
                        return @scales.x(new Date(a))
                    )
                .attr('cy', - (@options.ticksize + 3) * options.index + -(@options.ticksize-2)/2)
                .attr('fill', (a) =>
                    if(a[4]==false)
                        "transparent"
                    else
                        options.color

                    )
                .attr('stroke', d3.rgb(options.color).darker())
                .attr('stroke-width', 1)
                .attr('r', @options.ticksize/2)
                .on("mouseover", (d) =>
                    if (d[2])
                        @time_tooltip_is_on = false
                        @tooltip.transition()
                            .duration(100)
                            .style("opacity", .9)
                        @tooltip.html(d[2])
                            .style("left", (d3.event.pageX) + "px")
                            .style("top", (d3.event.pageY - 28) + "px")
                )
                .on("mousemove", (d) =>
                    @tooltip
                        .style("left", (d3.event.pageX) + "px")
                        .style("top", (d3.event.pageY - 28) + "px")
                )
                .on("mouseout", (d) =>
                    @time_tooltip_is_on = true
                    @tooltip.transition()
                        .duration(100)
                        .style("opacity", 0)
                ).on('click', (d) =>
                    @element.dispatchEvent(
                        new CustomEvent('coverageselected', {
                            detail: {
                                id: d[2],
                                bbox: d[3],
                                start: d[0],
                                end:d[1]
                            }
                            bubbles: true,
                            cancelable: true
                        })
                    )
                )

            p.exit().remove()

        drawPaths = (element, data, options) =>

            @scales.y.domain(d3.extent(data, (d) => d[1]))

            element.selectAll('path').remove()
            element.selectAll('.y.axis').remove()


            line = d3.svg.line()
                .x( (a)=> @scales.x(new Date(a[0])))
                .y( (a)=> @scales.y(a[1]))

            # TODO: Tests with clipping mask for better readability
            # element.attr("clip-path", "url(#clip)")

            # clippath = element.append("defs").append("svg:clipPath")
            #     .attr("id", "clip")

            # element.select("#clip").append("svg:rect")
            #         .attr("id", "clip-rect")
            #         .attr("x", (options.index+1)*30)
            #         .attr("y", -@options.height)
            #         .attr("width", 100)
            #         .attr("height", 100)

            element.append("path")
                #.attr("clip-path", "url(#clip)")
                .datum(data)
                .attr("class", "line")
                .attr("d", line)
                .attr('stroke', options.color)
                .attr('stroke-width', "1.5px")
                .attr('fill', 'none')
                .attr('transform', "translate(0,"+ (-@options.height+29)+")")


            step = (@scales.y.domain()[1] - @scales.y.domain()[0])/4
            @axis.y.tickValues(
                d3.range(@scales.y.domain()[0],@scales.y.domain()[1]+step, step)
            )

            element.append("g")
                .attr("class", "y axis")
                .attr('fill', options.color)
                .call(@axis.y)
                .attr("transform", "translate("+((options.index+1)*30)+","+ (-@options.height+29)+")")



            element.selectAll('.axis .domain')
                .attr("stroke-width", "1")
                .attr("stroke", options.color)
                .attr("shape-rendering", "crispEdges")
                .attr("fill", "none")

            element.selectAll('.axis line')
                .attr("stroke-width", "1")
                .attr("shape-rendering", "crispEdges")
                .attr("stroke", options.color)

            element.selectAll('.axis path')
                .attr("stroke-width", "1")
                .attr("shape-rendering", "crispEdges")
                .attr("stroke", options.color)





        @reloadDataset = (dataset) =>
            callback = debounce(@options.debounce, dataset, =>
                @data[dataset].callback(@scales.x.domain()[0], @scales.x.domain()[1], (id, data) =>
                    el = @svg.select("g.datasets #dataset-#{id}")
                    ranges = []
                    points = []
                    paths = []

                    for element in data
                        if(Array.isArray(element))
                            if(element.length == 3)
                                paths.push(element)
                            else
                                ranges.push(element)
                        else
                            if (!(element instanceof Date) && element.split("/").length>1)
                                elements = element.split("/")
                                elements.pop()
                                ranges.push(elements)
                            else
                                points.push(element)

                    @data[id].ranges = ranges
                    @data[id].points = points
                    @data[id].paths = paths
                    @updateDataset(id)
                , @bbox)
            )
            callback()


        for dataset in @options.datasets
            do (dataset) => @drawDataset(dataset)

        @redraw = =>

            # repaint the axis
            d3.select(@element)
                .select('g.mainaxis')
                  .call(@axis.x)
                .selectAll('text')
                  .attr('x', 1)
                  .style('text-anchor', 'start')

            # repaint brush
            @redrawBrush()

            # repaint the datasets
            # First paint lines and ticks
            for dataset of @data
                if !@data[dataset].lineplot
                    @reloadDataset(dataset)
                    @updateDataset(dataset)

            # Afterwards paint lines so they are not overlapped
            for dataset of @data
                if @data[dataset].lineplot
                    @reloadDataset(dataset)
                    @updateDataset(dataset)

            # repaint timetick
            drawTimetick()

        # resizing (the window)
        resize = =>
            # update the width of the element and the scales
            svg = d3.select(@element).select('svg.timeslider')[0][0]
            @options.width = if @useBBox then svg.getBBox().width else svg.clientWidth
            @scales.x.range([0, @options.width])

            @redraw()

        d3.select(window).on('resize', resize)

        # zooming & dragging
        @options.zoom = d3.behavior.zoom()
            .x(@scales.x)
            .size([@options.width, @options.height])
            .scaleExtent([1, Infinity])
            .on('zoom', @redraw)
        @svg.call(@options.zoom)

        if @options.display
            @center(@options.display.start, @options.display.end)

        hideTimeTooltip= =>
            @tooltip_time
                .transition()
                .duration(100)
                .style("opacity", 0)

        showTimeTooltip= (e)=>
            if not (@time_tooltip and @time_tooltip_is_on)
                return hideTimeTooltip()
            node = @svg[0][0]
            parent = if node.parentElement? then node.parentElement else node.parentNone
            coords = d3.mouse(node)
            node_offset = node.getBoundingClientRect()
            offset_x = @time_tooltip_offset[0] + node_offset.left
            offset_y = @time_tooltip_offset[1] + node_offset.top
            @tooltip_time
                .transition()
                .duration(100)
                .style("opacity", .9)
            @tooltip_time
                .html(@timeFormat(@scales.x.invert(coords[0])))
                .style("left", (offset_x + coords[0]) + "px")
                .style("top", (offset_y + coords[1]) + "px")

        @svg
            .on('mousemove', showTimeTooltip)
            .on('mouseout', hideTimeTooltip)


    # tooltip control

    setBrushTooltip: (active) ->
        @brush_tooltip = active

    setBrushTooltipOffset: (offset) ->
        @brush_tooltip_offset = offset

    setTimeTooltip: (active) ->
        @time_tooltip = active

    setTimeTooltipOffset: (offset) ->
        @time_tooltip_offset = offset


    # Function pair to allow for easy hiding and showing the time slider
    hide: ->
        console.log('hide')
        @originalDisplay = @element.style.display
        @element.style.display = 'none'
        true

    show: ->
        console.log('show')
        @element.style.display = @originalDisplay
        @redraw()
        true

    domain: (params...) ->
        # TODO: more thorough input checking
        return false unless params.length == 2

        start = new Date(params[0])
        end = new Date(params[1])
        [ start, end ] = [ end, start ] if end < start

        @options.domain.start = start
        @options.domain.end = end

        @scales.x.domain([ @options.domain.start, @options.domain.end ])
        @redraw()

        true

    select: (params...) ->
        # update the time selection (brush)
        return false unless params.length == 2

        start = new Date(params[0])
        end = new Date(params[1])
        [ start, end ] = [ end, start ] if end < start

        start = @options.start if start < @options.start
        end = @options.end if end > @options.end

        @brushExtent = [start, end]

        @redrawBrush()
        @element.dispatchEvent(new CustomEvent('selectionChanged', {
            detail: {start: start, end: end}
            bubbles: true,
            cancelable: true
        }))
        true

    addDataset: (dataset) ->
        @drawDataset(dataset)
        true

    removeDataset: (id) ->
        return false unless @data[id]?

        i = @data[id].index
        lp = @data[id].lineplot
        delete @data[id]

        if lp
            @options.linegraphIndex--
        else
            @options.datasetIndex--

        d3.select(@element).select("g.dataset#dataset-#{id}").remove()

        for dataset of @data
            if lp == @data[dataset].lineplot
                @data[dataset].index -= 1 if @data[dataset].index > i

        @redraw()
        true

    # TODO
    center: (params...) ->
        start = new Date(params[0])
        end = new Date(params[1])
        [ start, end ] = [ end, start ] if end < start

        @options.zoom.scale((@options.domain.end - @options.domain.start) / (end - start))
        @options.zoom.translate([ @options.zoom.translate()[0] - @scales.x(start), 0 ])

        @redraw()

        true

    zoom: (params...) ->
        start = new Date(params[0])
        end = new Date(params[1])
        [ start, end ] = [ end, start ] if end < start

        d3.transition().duration(750).tween('zoom', =>
            iScale = d3.interpolate(@options.zoom.scale(),
                (@options.domain.end - @options.domain.start) / (end - start))
            return (t) =>
                iPan = d3.interpolate(@options.zoom.translate()[0], @options.zoom.translate()[0] - @scales.x(start))

                @options.zoom.scale(iScale(t))
                @options.zoom.translate([ (iPan(t)), 0 ])

                # redraw
                @redraw()
        )

        true

    reset: ->
        @zoom(@options.domain.start, @options.domain.end)
        true

    updateBBox: (bbox, id) ->
        return false unless @data[id]?
        @bbox = bbox
        #d3.select(@element).select("g.dataset#dataset-#{id}").remove()
        @reloadDataset(id)

        true


class TimeSlider.Plugin

# Export the TimeSlider object for use in the browser
this.TimeSlider = TimeSlider
