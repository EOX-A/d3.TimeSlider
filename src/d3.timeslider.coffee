d3 = require 'd3'
debounce = require 'debounce'


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
        @brushTooltip = false
        @brushTooltipOffset = [30, 20]

        @tooltip = d3.select("body").append("div")
            .attr("class", "tooltip")
            .style("opacity", 0)

        @tooltipBrushMin = d3.select("body").append("div")
            .attr("class", "tooltip")
            .style("opacity", 0)
        @tooltipBrushMax = d3.select("body").append("div")
            .attr("class", "tooltip")
            .style("opacity", 0)

        # used for show()/hide()
        @originalDisplay = @element.style.display

        # create the root svg element
        @svg = d3.select(@element).append('svg')
            .attr('class', 'timeslider')


        # TODO: what does this do???

        @useBBox = false
        if @svg[0][0].clientWidth == 0
            d3.select(@element).select('svg')
                .append('rect').attr('width', '100%')
                .attr('height', '100%')
                .attr('opacity', '0')
            @useBBox = true

        # default options and other variables for later
        if @useBBox
            @options.width = @svg[0][0].getBBox().width
            @options.height = @svg[0][0].getBBox().height
        else
            @options.width = @svg[0][0].clientWidth
            @options.height = @svg[0][0].clientHeight

        @options.brush ||= {}
        @options.brush.start ||= @options.start
        @options.brush.end ||= new Date(new Date(@options.brush.start).setDate(@options.brush.start.getDate() + 3))
        @options.debounce ||= 50
        @options.ticksize ||= 3
        @options.datasets ||= []
        @options.selectionLimit ||= -1

        @recordFilter = @options.recordFilter

        # object to hold individual data points / data ranges
        @datasets = {}
        @ordinal = 0

        @timetickDate = false
        @simplifyDate = d3.time.format.utc("%d.%m.%Y - %H:%M:%S")

        customFormats = d3.time.format.utc.multi([
            [".%L", (d) -> d.getUTCMilliseconds() ]
            [":%S", (d) -> d.getUTCSeconds() ],
            ["%H:%M", (d) -> d.getUTCMinutes() ],
            ["%H:%M", (d) -> d.getUTCHours() ],
            ["%b %d %Y ", (d) ->d.getUTCDay() && d.getUTCDate() != 1 ],
            ["%b %d %Y", (d) -> d.getUTCDate() != 1 ],
            ["%B %Y", (d) -> d.getUTCMonth() ],
            ["%Y", -> true ]
        ])

        # scales
        @scales = {
            x: d3.time.scale.utc()
                .domain([ @options.domain.start, @options.domain.end ])
                .range([0, @options.width])
            y: d3.scale.linear()
                .range([@options.height-29, 0])
        }

        # axis
        @axis = {
            x: d3.svg.axis()
                .scale(@scales.x)
                .innerTickSize(@options.height - 15)
                .tickFormat(customFormats)
            y: d3.svg.axis()
                .scale(@scales.y)
                .orient("left")
        }

        @svg.append('g')
            .attr('class', 'mainaxis')
            .call(@axis.x)

        # translate the main x axis
        d3.select(@element).select('g.mainaxis .domain')
            .attr('transform', "translate(0, #{@options.height - 18})")

        @setBrushTooltip = (active) =>
            @brushTooltip = active

        @setBrushTooltipOffset = (offset) =>
            @brushTooltipOffset = offset

        # create the brush with all necessary event callbacks
        @brush = d3.svg.brush()
            .x(@scales.x)
            .on('brushstart', =>
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
                @options.zoom
                    .scale(@options.lastZoom.scale)
                    .translate(@options.lastZoom.translate)
                    .on('zoom', => @redraw)

                # Check for selection limit and reduce to correct size
                if @options.selectionLimit > 0
                    @svg.selectAll('.brush')
                        .attr({fill: "#333"})
                    s = @brush.extent()
                    if (s[1]-s[0])/1000 >= @options.selectionLimit
                        tmpdate = new Date(@brush.extent()[0].getTime() + @options.selectionLimit * 1000)
                        @brush.extent([@brush.extent()[0], tmpdate])
                        d3.select(@element).select('g.brush').call(@brush)

                @element.dispatchEvent(
                    new CustomEvent('selectionChanged', {
                        detail: {
                            start: @brush.extent()[0],
                            end: @brush.extent()[1]
                        }
                        bubbles: true,
                        cancelable: true
                    })
                )

                if (@brushTooltip)
                    @tooltipBrushMin.transition()
                        .duration(100)
                        .style("opacity", 0)

                    @tooltipBrushMax.transition()
                        .duration(100)
                        .style("opacity", 0)

            )
            .on('brush', =>
                # Check for selection limit, warn in red if selection is to big
                if @options.selectionLimit > 0
                    s = @brush.extent()
                    if (s[1]-s[0]) / 1000 > @options.selectionLimit
                        @svg.selectAll('.brush')
                            .attr({fill: "red"})

                    else
                        @svg.selectAll('.brush')
                            .attr({fill: "#333"})

                if @brushTooltip
                    offheight = 0
                    if @svg[0][0].parentElement?
                        offheight = @svg[0][0].parentElement.offsetHeight
                    else
                        offheight = @svg[0][0].parentNode.offsetHeight
                    @options.zoom
                        .scale(@options.lastZoom.scale)
                        .translate(@options.lastZoom.translate)

                    @tooltipBrushMin.transition()
                        .duration(100)
                        .style("opacity", .9)
                    @tooltipBrushMin.html(@simplifyDate(@brush.extent()[0]))
                        .style("left", (@scales.x(@brush.extent()[0])+@brushTooltipOffset[0]) + "px")
                        .style("top", (offheight + @brushTooltipOffset[1]) + "px")


                    @tooltipBrushMax.transition()
                        .duration(100)
                        .style("opacity", .9)
                    @tooltipBrushMax.html(@simplifyDate(@brush.extent()[1]))
                        .style("left", (@scales.x(@brush.extent()[1])+@brushTooltipOffset[0]) + "px")
                        .style("top", (offheight + @brushTooltipOffset[1] + 20) + "px")

            )
            .extent([@options.brush.start, @options.brush.end])

        # add a group to draw the brush in
        @svg.append('g')
            .attr('class', 'brush')
            .call(@brush)
            .selectAll('rect')
                .attr('height', "#{@options.height - 19}")
                .attr('y', 0)

        # add a group that contains all datasets
        @svg.append('g')
            .attr('class', 'datasets')
            .attr('width', @options.width)
            .attr('height', @options.height)
            .attr('transform', "translate(0, #{@options.height - 23})")

        # handle window resizes
        d3.select(window)
            .on('resize', =>
                # update the width of the element and the scales
                svg = d3.select(@element).select('svg.timeslider')[0][0]
                @options.width = if @useBBox then svg.getBBox().width else svg.clientWidth
                @scales.x.range([0, @options.width])

                @redraw()
            )

        # create the zoom behavior
        @options.zoom = d3.behavior.zoom()
            .x(@scales.x)
            .size([@options.width, @options.height])
            .scaleExtent([1, Infinity])
            .on('zoom', => @redraw())
        @svg.call(@options.zoom)

        # initialize all datasets
        for definition in @options.datasets
            do (definition) => @addDataset(definition)

        # show the initial time span
        if @options.display
            @center(@options.display.start, @options.display.end)

    ###
    ## Private API
    ###

    redraw: ->
        # update brush
        @brush.x(@scales.x).extent(@brush.extent())

        # repaint the axis and the brush
        d3.select(@element).select('g.mainaxis').call(@axis.x)
        d3.select(@element).select('g.brush').call(@brush)

        # repaint the datasets
        # First paint lines and ticks
        for dataset of @datasets
            if !@datasets[dataset].lineplot
                @reloadDataset(dataset)
                @redrawDataset(dataset)

        # Afterwards paint lines so they are not overlapped
        for dataset of @datasets
            if @datasets[dataset].lineplot
                @reloadDataset(dataset)
                @redrawDataset(dataset)

        # repaint timetick
        # TODO: is this unneccessary
        #@drawTimetick()

    # TODO: this method seems quite unused
    # drawTimetick: ->
    #     @svg.selectAll('.timetick').remove()

    #     # TODO: @timetickDate seems to be set nowhere, so this is obviously never called???


    #     if (Object.prototype.toString.call(@timetickDate) == '[object Date]')

    #         r = @svg.selectAll('.timetick')
    #             .data([@timetickDate])

    #         r.enter().append('rect')
    #             .attr('class', 'timetick')
    #             .attr('x', (a) =>  @scales.x(a) )
    #             .attr('y', 0 )
    #             .attr('width', (a) ->  1 )
    #             .attr('height', (@options.height-20))
    #             .attr('stroke', 'red')
    #             .attr('stroke-width', 1)
    #             .attr('fill', (a) -> options.color)  # TODO: what color?

    #         r.exit().remove()


    # Convenience method to hook up a single record elements events
    setupRecord: (recordElement, dataset) ->
        recordElement.attr('fill', (record) =>
            if not @recordFilter or @recordFilter(record, dataset)
                dataset.color
            else
                "transparent"
        )
        .on("mouseover", (record) =>
            params = record[2]
            @element.dispatchEvent(
                new CustomEvent('recordMouseover', {
                    detail: {
                        dataset: dataset.id,
                        start: record[0],
                        end: record[1],
                        params: params
                    }
                    bubbles: true,
                    cancelable: true
                })
            )

            if params and (params.id or params.name)
                @tooltip.transition()
                    .duration(200)
                    .style("opacity", .9)
                @tooltip.html(params.id or params.name)
                    .style("left", (d3.event.pageX) + "px")
                    .style("top", (d3.event.pageY - 28) + "px")
        )
        .on("mouseout", (record) =>
            @element.dispatchEvent(
                new CustomEvent('recordMouseout', {
                    detail: {
                        dataset: dataset.id,
                        start: record[0],
                        end: record[1],
                        params: record[2]
                    }
                    bubbles: true,
                    cancelable: true
                })
            )
            @tooltip.transition()
                .duration(500)
                .style("opacity", 0)
        )
        .on('click', (record) =>
            @element.dispatchEvent(
                new CustomEvent('recordClicked', {
                    detail: {
                        dataset: dataset.id,
                        start: record[0],
                        end: record[1],
                        params: record[2]
                    }
                    bubbles: true,
                    cancelable: true
                })
            )
        )

    drawRanges: (datasetElement, dataset, records) ->
        datasetElement.selectAll('rect').remove()

        r = datasetElement.selectAll('rect')
            .data(records)

        r.enter().append('rect')
            .attr('x', (record) => @scales.x(new Date(record[0])) )
            .attr('y', - (@options.ticksize + 3) * dataset.index + -(@options.ticksize-2) )
            .attr('width', (record) => @scales.x(new Date(record[1])) - @scales.x(new Date(record[0])) )
            .attr('height', (@options.ticksize-2))
            .attr('stroke', d3.rgb(dataset.color).darker())
            .attr('stroke-width', 1)
            .call((recordElement) => @setupRecord(recordElement, dataset))

        r.exit().remove()

    drawPoints: (datasetElement, dataset, records) ->
        datasetElement.selectAll('circle').remove()
        p = datasetElement.selectAll('circle')
            .data(records)

        p.enter().append('circle')
            .attr('cx', (a) =>
                if Array.isArray(a)
                    return @scales.x(new Date(a[0]))
                else
                    return @scales.x(new Date(a))
            )
            .attr('cy', - (@options.ticksize + 3) * dataset.index - (@options.ticksize - 2) / 2)
            .attr('stroke', d3.rgb(dataset.color).darker())
            .attr('stroke-width', 1)
            .attr('r', @options.ticksize / 2)
            .call((recordElement) => @setupRecord(recordElement, dataset))

        p.exit().remove()

    drawPaths: (datasetElement, dataset, data) ->
        @scales.y.domain(d3.extent(data, (d) -> d[1]))

        datasetElement.selectAll('path').remove()
        datasetElement.selectAll('.y.axis').remove()

        line = d3.svg.line()
            .x( (a) => @scales.x(new Date(a[0])) )
            .y( (a) => @scales.y(a[1]) )

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

        datasetElement.append("path")
            #.attr("clip-path", "url(#clip)")
            .datum(data)
            .attr("class", "line")
            .attr("d", line)
            .attr('stroke', dataset.color)
            .attr('stroke-width', "1.5px")
            .attr('fill', 'none')
            .attr('transform', "translate(0,"+ (-@options.height+29)+")")


        step = (@scales.y.domain()[1] - @scales.y.domain()[0])/4
        @axis.y.tickValues(
            d3.range(@scales.y.domain()[0],@scales.y.domain()[1]+step, step)
        )

        datasetElement.append("g")
            .attr("class", "y axis")
            .attr('fill', dataset.color)
            .call(@axis.y)
            .attr("transform", "translate("+((dataset.index+1)*30)+","+ (-@options.height+29)+")")

        datasetElement.selectAll('.axis .domain')
            .attr("stroke-width", "1")
            .attr("stroke", dataset.color)
            .attr("shape-rendering", "crispEdges")
            .attr("fill", "none")

        datasetElement.selectAll('.axis line')
            .attr("stroke-width", "1")
            .attr("shape-rendering", "crispEdges")
            .attr("stroke", dataset.color)

        datasetElement.selectAll('.axis path')
            .attr("stroke-width", "1")
            .attr("shape-rendering", "crispEdges")
            .attr("stroke", dataset.color)

    # this function acually draws a dataset

    redrawDataset: (datasetId) ->
        dataset = @datasets[datasetId]
        if not dataset
            return

        records = dataset.getRecords()
        paths = dataset.getPaths()
        index = dataset.index
        color = dataset.color

        if paths and paths.length
            @drawPaths(dataset.element, dataset, paths)
        else if records and records.length
            points = dataset.getRecords().filter((record) =>
                (@scales.x(new Date(record[1])) - @scales.x(new Date(record[0]))) < 5
            )
            ranges = dataset.getRecords().filter((record) =>
                (@scales.x(new Date(record[1])) - @scales.x(new Date(record[0]))) >= 5
            )
            @drawRanges(dataset.element, dataset, ranges)
            @drawPoints(dataset.element, dataset, points)

    # this function triggers the reloading of a dataset (sync)

    reloadDataset: (datasetId) ->
        dataset = @datasets[datasetId]
        [ start, end ] = @scales.x.domain()

        # start the dataset synchronization
        dataset.syncDebounced(start, end, (records, paths) =>
            finalRecords = []
            finalPaths = []

            if !dataset.lineplot
                for record in records
                    if record instanceof Date
                        record = [ record, record ]

                    else if not (record[1] instanceof Date)
                        record = [ record[0], record[0] ].concat(record[1..])

                    # TODO: implement other data conversions

                    finalRecords.push(record)

                    # if record[0] instanceof Date and record[1] instanceof Date
                    #     ranges.push(record)
                    # else
                    #     points.push(record)

                    # TODO: implement paths

                    # if Array.isArray(record)
                    #     if record.length == 3
                    #         paths.push(record)
                    #     else
                    #         ranges.push(record)
                    # else if record instanceof Date
                    #     points.push(record)

                    # # TODO: keep this?
                    # else if record.split("/").length > 1
                    #     elements = record.split("/")
                    #     elements.pop()
                    #     ranges.push(elements)
            else
                # TODO: perform check of records
                finalPaths = records

            dataset.setRecords(finalRecords)
            dataset.setPaths(finalPaths)
            @redrawDataset(datasetId)
        )


    ###
    ## Public API
    ###

    # convenience funtion to hide the TimeSlider
    hide: ->
        @element.style.display = 'none'
        true

    # convenience function to show a previously hidden TimeSlider
    show: ->
        @element.style.display = @originalDisplay
        true

    # set a new domain of the TimeSlider. redraws.
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

    # select the specified time span
    select: (params...) ->
        return false unless params.length == 2

        start = new Date(params[0])
        end = new Date(params[1])
        [ start, end ] = [ end, start ] if end < start

        start = @options.start if start < @options.start
        end = @options.end if end > @options.end

        d3.select(@element).select('g.brush')
            .call(@brush.extent([start, end]))
        @element.dispatchEvent(new CustomEvent('selectionChanged', {
            detail: {
                start: @brush.extent()[0],
                end: @brush.extent()[1]
            }
            bubbles: true,
            cancelable: true
        }))
        true

    # add a dataset to the TimeSlider. redraws.
    # the dataset definition shall have the following values:
    #  *
    #
    addDataset: (definition) ->
        @options.datasetIndex = 0 unless @options.datasetIndex?
        @options.linegraphIndex = 0 unless @options.linegraphIndex?

        index = @options.datasetIndex
        lineplot = false

        id = definition.id
        @ordinal++

        if !definition.lineplot
            index = @options.datasetIndex++
            @svg.select('g.datasets')
                .insert('g',':first-child')
                    .attr('class', 'dataset')
                    .attr('id', "dataset-#{@ordinal}")
        else
            index = @options.linegraphIndex++
            lineplot = true
            @svg.select('g.datasets')
                .append('g')
                    .attr('class', 'dataset')
                    .attr('id', "dataset-#{@ordinal}")

        element = @svg.select("g.datasets #dataset-#{@ordinal}")

        @datasets[id] = new Dataset({
            id: id,
            index: index,
            color: definition.color,
            source: definition.source,
            records: definition.records,
            lineplot: lineplot,
            debounceTime: @options.debounce,
            ordinal: @ordinal,
            element: element
        })

        @reloadDataset(id)

    # remove a dataset. redraws.
    removeDataset: (id) ->
        return false unless @datasets[id]?

        dataset = @datasets[id]
        i = dataset.index
        lp = dataset.lineplot
        ordinal = dataset.ordinal
        delete @datasets[id]

        if lp
            @options.linegraphIndex--
        else
            @options.datasetIndex--

        d3.select(@element).select("g.dataset#dataset-#{ordinal}").remove()

        for dataset of @datasets
            if lp == @datasets[dataset].lineplot
                @datasets[dataset].index -= 1 if @datasets[dataset].index > i

        @redraw()
        true

    hasDataset: (id) ->
        return false unless @datasets[id]?

    # TODO redraws.
    center: (params...) ->
        start = new Date(params[0])
        end = new Date(params[1])
        [ start, end ] = [ end, start ] if end < start

        @options.zoom.scale((@options.domain.end - @options.domain.start) / (end - start))
        @options.zoom.translate([ @options.zoom.translate()[0] - @scales.x(start), 0 ])

        @redraw()

        true

    # zoom to start/end. redraws.
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

    # reset the zoom to the initial domain
    reset: ->
        @zoom(@options.domain.start, @options.domain.end)
        true

    # enable or disable the brush tooltip
    setBrushTooltip: (@brushTooltip) ->

    # set the offset of the brush tooltip
    setBrushTooltipOffset: (@brushTooltipOffset) ->

    # sets a new record filter. This shall be a a callable that shall handle a
    # single record. redraws.
    setRecordFilter: (@recordFilter) ->
        @redraw()
        true


# Dataset utility class for internal use only
class Dataset
    constructor: (options) ->
        { @id,  @color, @source, @sourceParams, @index, @records, @paths, @lineplot, @ordinal, @element } = options
        @syncDebounced = debounce(@sync, options.debounceTime)

    getSource: ->
        @source

    setSource: (@source) ->

    setRecords: (@records) ->

    getRecords: -> @records

    setPaths: (@paths) ->

    getPaths: -> @paths

    sync: (start, end, callback) ->
        # sources conforming to the Source interface
        if @source and typeof @source.fetch == "function"
            @source.fetch start, end, @sourceParams, (records, paths) ->
                callback(records, paths)
        # sources that are functions
        else if typeof @source == "function"
            @source start, end, @sourceParams, (records, paths) ->
                callback(records, paths)
        # no source, simply call the callback with the static records and paths
        else
            callback(@records, @paths)


# Interface for a source
class Source
    fetch: (start, end, params, callback) ->

TimeSlider.Plugin = {}

module.exports = TimeSlider
