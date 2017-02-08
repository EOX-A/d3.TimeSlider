d3 = require 'd3'
{ split, intersects, merged, after, subtract, parseDuration, offsetDate, centerTooltipOn, pixelWidth } = require './utils.coffee'
EventEmitter = require './event-emitter.coffee'

RecordDataset = require './datasets/record-dataset.coffee'
BucketDataset = require './datasets/bucket-dataset.coffee'
PathDataset = require './datasets/path-dataset.coffee'

class TimeSlider extends EventEmitter

    # TODO
    #  * Implement a function to fetch dataset information from a WMS / WCS service
    #  * Compute the padding at the left & right of the timeslider
    #  * TESTING

    constructor: (@element, @options = {}) ->
        super(@element)
        @brushTooltip = @options.brushTooltip
        @brushTooltipOffset = [30, 20]

        @tooltip = d3.select(@element).append("div")
            .attr("class", "timeslider-tooltip")
            .style("opacity", 0)

        @tooltipBrushMin = d3.select(@element).append("div")
            .attr("class", "timeslider-tooltip")
            .style("opacity", 0)
        @tooltipBrushMax = d3.select(@element).append("div")
            .attr("class", "timeslider-tooltip")
            .style("opacity", 0)

        @tooltipFormatter = @options.tooltipFormatter || (record) -> record[2]?.id || record[2]?.name
        @binTooltipFormatter = @options.binTooltipFormatter || (bin) =>
            bin.map(@tooltipFormatter)
                .filter((tooltip) -> tooltip?)
                .join("<br>")

        # used for show()/hide()
        @originalDisplay = @element.style.display

        # create the root svg element
        @svg = d3.select(@element).append('svg')
            .attr('class', 'timeslider')


        ### TODO: what does this do??? ###

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

        ### END-TODO ###

        @options.selectionLimit = if @options.selectionLimit then parseDuration(@options.selectionLimit) else null

        @options.brush ||= {}
        @options.brush.start ||= @options.start
        if @options.selectionLimit
            @options.brush.end ||= offsetDate(@options.brush.start, @options.selectionLimit)
        else
            @options.brush.end ||= new Date(new Date(@options.brush.start).setDate(@options.brush.start.getDate() + 3))

        @selectionConstraint = [
            offsetDate(@options.brush.start, -@options.selectionLimit),
            offsetDate(@options.brush.end, @options.selectionLimit)
        ]

        domain = @options.domain

        @options.displayLimit = if @options.displayLimit then parseDuration(@options.displayLimit) else null
        @options.display ||= {}
        if not @options.display.start and @options.displayLimit
            @options.display.start = offsetDate(domain.end, -@options.displayLimit)
        else
            @options.display.start ||= domain.start
        @options.display.end ||= domain.end

        if @options.displayLimit != null and (@options.display.end - @options.display.start) > @options.displayLimit * 1000
            @options.display.start = offsetDate(@options.display.end, -@options.displayLimit)

        @options.debounce ||= 50
        @options.ticksize ||= 3
        @options.datasets ||= []

        @recordFilter = @options.recordFilter

        # object to hold individual data points / data ranges
        @datasets = {}
        @ordinal = 0

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
                .domain([ @options.display.start, @options.display.end ])
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
                # deactivate zoom behavior
                @brushing = true
                @prevTranslate = @options.zoom.translate()
                @prevScale = @options.zoom.scale()
                @selectionConstraint = null

                # show the brush tooltips
                if @brushTooltip
                    @tooltipBrushMin.transition()
                        .duration(100)
                        .style("opacity", .9)
                    @tooltipBrushMax.transition()
                        .duration(100)
                        .style("opacity", .9)
            )
            .on('brushend', =>
                @brushing = false
                @options.zoom.translate(@prevTranslate)
                @options.zoom.scale(@prevScale)

                @checkBrush()
                @redraw()

                @selectionConstraint = null

                # dispatch the events
                @dispatch('selectionChanged', {
                    start: @brush.extent()[0],
                    end: @brush.extent()[1]
                })

                # hide the brush tooltips
                if @brushTooltip
                    @tooltipBrushMin.transition()
                        .duration(100)
                        .style("opacity", 0)
                    @tooltipBrushMax.transition()
                        .duration(100)
                        .style("opacity", 0)

                @wasBrushing = true
            )
            .on('brush', =>
                if @options.selectionLimit != null
                    if @selectionConstraint == null
                        [low, high] = @brush.extent()
                        @selectionConstraint = [
                            offsetDate(high, - @options.selectionLimit),
                            offsetDate(low, @options.selectionLimit)
                        ]
                    else
                        if d3.event.mode == "move"
                            [low, high] = @brush.extent()
                            @selectionConstraint = [
                                offsetDate(high, - @options.selectionLimit),
                                offsetDate(low, @options.selectionLimit)
                            ]
                        @checkBrush()

                @redraw()
            )
            .extent([@options.brush.start, @options.brush.end])

        @svg.append('g')
            .attr('class', 'highlight')
            .selectAll('rect')
                .attr('height', "#{@options.height - 19}")
                .attr('y', 0)

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
        minScale = (@options.display.start - @options.display.end) / (@options.domain.start - @options.domain.end)
        if !@options.constrain
            minScale = 0
        # Calculate maxScale by gettting milliseconds difference  of the displayed
        # time domain (getting the seconds by dividing by 1000) and halving it.
        # This should allow to zoom into to see up to two seconds in the complete timeslider
        maxScale = Math.abs(@options.display.start - @options.display.end)/2000

        @options.zoom = d3.behavior.zoom()
            .x(@scales.x)
            .size([@options.width, @options.height])
            .scaleExtent([minScale, maxScale])
            .on('zoomstart', =>
                @prevScale2 = @options.zoom.scale()
                @prevDomain = @scales.x.domain()
            )
            .on('zoom', =>
                if @brushing
                    @options.zoom.scale(@prevScale)
                    @options.zoom.translate(@prevTranslate)
                else
                    if @options.displayLimit != null and d3.event.scale < @prevScale2
                        [low, high] = @scales.x.domain()

                        if (high.getTime() - low.getTime()) > @options.displayLimit * 1000
                            [start, end] = @prevDomain
                        else
                            [start, end] = @scales.x.domain()

                    else
                        [start, end] = @scales.x.domain()

                    @center(start, end, false)
                    @prevScale2 = @options.zoom.scale()
                    @prevDomain = @scales.x.domain()
            )
            .on('zoomend', =>
                display = @scales.x.domain()
                @dispatch('displayChanged', {
                    start: display[0],
                    end: display[1]
                })
                if not @wasBrushing
                    for dataset of @datasets
                        @reloadDataset(dataset)
                @wasBrushing = false
            )
        @svg.call(@options.zoom)

        # initialize all datasets
        for definition in @options.datasets
            do (definition) => @addDataset(definition)

        # show the initial time span
        if @options.display
            @center(@options.display.start, @options.display.end)

        # If controls are configured add them here
        if @options.controls
            d3.select(@element).append("div")
                .attr("id", "pan-left")
                .attr("class", "control")
                .on("click", ()=>
                    [s,e] = @scales.x.domain()
                    d = Math.abs(e-s)/10
                    s = new Date(s.getTime()-d)
                    e = new Date(e.getTime()-d)
                    @center(s,e)
                )
                .append("div")
                    .attr("class", "arrow-left")

            d3.select(@element).append("div")
                .attr("id", "pan-right")
                .attr("class", "control")
                .on("click", ()=>
                    [s,e] = @scales.x.domain()
                    d = Math.abs(e-s)/10
                    s = new Date(s.getTime()+d)
                    e = new Date(e.getTime()+d)
                    @center(s,e)
                )
                .append("div")
                    .attr("class", "arrow-right")

            d3.select(@element).append("div")
                .attr("id", "zoom-in")
                .attr("class", "control")
                .text("+")
                .on("click", ()=>
                    [s,e] = @scales.x.domain()
                    d = Math.abs(e-s)/10
                    s = new Date(s.getTime()+(d/2))
                    e = new Date(e.getTime()-(d/2))
                    if (e - s) < 2 * 1000
                        [s, e] = @scales.x.domain()
                    @center(s,e)
                )

            d3.select(@element).append("div")
                .attr("id", "zoom-out")
                .attr("class", "control")
                .html("&ndash;")
                .on("click", ()=>
                    [s,e] = @scales.x.domain()
                    d = Math.abs(e-s)/10
                    s = new Date(s.getTime()-(d/2))
                    e = new Date(e.getTime()+(d/2))
                    [low, high] = @scales.x.domain()
                    if @options.displayLimit != null and
                       (e - s) > @options.displayLimit * 1000
                        [s, e] = @scales.x.domain()
                    @center(s,e)
                )

            d3.select(@element).append("div")
                .attr("id", "reload")
                .attr("class", "control")
                .on("click", ()=>
                    for dataset of @datasets
                        @reloadDataset(dataset, true)
                )
                .append("div")
                    .attr("class", "reload-arrow")



    ###
    ## Private API
    ###

    checkBrush: ->
        if @selectionConstraint
            [a, b] = @selectionConstraint
            [x, y] = @brush.extent()

            if x < a
                x = a
            if y > b
                y = b

            @brush.extent([x, y])

    redraw: ->
        # update brush
        @brush.x(@scales.x).extent(@brush.extent())

        # repaint the axis and the brush
        d3.select(@element).select('g.mainaxis').call(@axis.x)
        d3.select(@element).select('g.brush').call(@brush)

        # redraw brushes
        if @brushTooltip
            offheight = 0
            if @svg[0][0].parentElement?
                offheight = @svg[0][0].parentElement.offsetHeight
            else
                offheight = @svg[0][0].parentNode.offsetHeight

            @tooltipBrushMin.html(@simplifyDate(@brush.extent()[0]))
            @tooltipBrushMax.html(@simplifyDate(@brush.extent()[1]))

            centerTooltipOn(@tooltipBrushMin, d3.select(@element).select('g.brush .extent')[0][0], 'left', [0, -20])
            centerTooltipOn(@tooltipBrushMax, d3.select(@element).select('g.brush .extent')[0][0], 'right')

        brushExtent = d3.select(@element).select('g.brush .extent')
        if parseFloat(brushExtent.attr('width')) < 1
            brushExtent.attr('width', 1)

        # pass everything necessary to draw
        drawOptions =
            height: @options.height,
            ticksize: @options.ticksize
            scales: @scales,
            axes: @axis,
            recordFilter: @recordFilter,
            tooltip: @tooltip,
            tooltipFormatter: @tooltipFormatter,
            binTooltipFormatter: @binTooltipFormatter

        @drawHighlights()

        [ start, end ] = @scales.x.domain()
        # repaint the datasets
        # First paint lines and ticks
        for datasetId of @datasets
            dataset = @datasets[datasetId]
            if !dataset.lineplot
                dataset.draw(start, end, drawOptions)

        # Afterwards paint lines so they are not overlapped
        for datasetId of @datasets
            dataset = @datasets[datasetId]
            if dataset.lineplot
                dataset.draw(start, end, drawOptions)

        # add classes to the ticks. When we are dealing with dates
        # (i.e: ms, s, m and h are zero), add the tick-date class
        d3.select(@element).selectAll('.mainaxis g.tick text')
            .classed('tick-date', (d) -> !(
                d.getUTCMilliseconds() | d.getUTCSeconds() | d.getUTCMinutes() | d.getUTCHours()
            ))

    drawHighlights: () ->
        #draw the highlighted interval
        d3.select(@element).selectAll('.highlight .interval').remove()
        if @highlightInterval
            start = @highlightInterval.start
            end = @highlightInterval.end
            left = @scales.x(start)
            width = pixelWidth([start, end], @scales.x)
            right = left + width
            height = @options.height - 19

            d3.select(@element).selectAll('.highlight').append('rect')
                .attr('class', 'interval')
                .attr('x', left)
                .attr('width', width)
                .attr('y', 0)
                .attr('height', height)
                .attr('stroke', @highlightInterval.strokeColor)
                .attr('stroke-width', 1)
                .attr('fill', @highlightInterval.fillColor)
            if @highlightInterval.outsideColor
                if left > 0
                    d3.select(@element).selectAll('.highlight').append('rect')
                        .attr('class', 'interval')
                        .attr('x', 0)
                        .attr('width', left)
                        .attr('y', 0)
                        .attr('height', height)
                        .attr('fill', @highlightInterval.outsideColor)
                d3.select(@element).selectAll('.highlight').append('rect')
                    .attr('class', 'interval')
                    .attr('x', right)
                    .attr('width', 2000)
                    .attr('y', 0)
                    .attr('height', height)
                    .attr('fill', @highlightInterval.outsideColor)

    # this function triggers the reloading of a dataset (sync)
    reloadDataset: (datasetId, clearCaches = false) ->
        dataset = @datasets[datasetId]

        # TODO: adjust
        [ start, end ] = @scales.x.domain()

        if clearCaches
            dataset.clearCaches()

        syncOptions =
            height: @options.height,
            ticksize: @options.ticksize
            scales: @scales,
            axes: @axis,
            recordFilter: @recordFilter,
            tooltip: @tooltip,
            tooltipFormatter: @tooltipFormatter,
            binTooltipFormatter: @binTooltipFormatter

        # start the dataset synchronization
        dataset.sync(start, end, syncOptions)

    # add the 'loading' class to the timeslider if any dataset is syncing
    checkLoading: () ->
        isLoading = false
        for id of @datasets
            isLoading = true if @datasets[id].isSyncing()

        @svg.classed('loading', isLoading)
        d3.select('.reload-arrow').classed('arrowloading', isLoading)

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

        @dispatch(
            'selectionChanged',
            {start: @brush.extent()[0],end: @brush.extent()[1]},
            @element
        )
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

        datasetOptions = {
            id: id,
            index: index,
            color: definition.color,
            highlightFillColor: definition.highlightFillColor,
            highlightStrokeColor: definition.highlightStrokeColor,
            source: definition.source,
            bucketSource: definition.bucketSource,
            records: definition.records,
            lineplot: lineplot,
            debounceTime: @options.debounce,
            ordinal: @ordinal,
            element: element,
            histogramThreshold: definition.histogramThreshold,
            histogramBinCount: definition.histogramBinCount,
            cacheRecords: definition.cacheRecords,
            cluster: definition.cluster
        }

        if definition.lineplot
            dataset = new PathDataset(datasetOptions)
        else if definition.bucket
            dataset = new BucketDataset(datasetOptions)
        else
            dataset = new RecordDataset(datasetOptions)

        # redraw whenever a dataset is synced
        dataset.on('syncing', =>
            @checkLoading()
        )
        dataset.on('synced', =>
            @redraw()
            @checkLoading()
        )

        @datasets[id] = dataset
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

    # redraws.
    center: (start, end, doReload = true) ->
        start = new Date(start)
        end = new Date(end)
        [ start, end ] = [ end, start ] if end < start

        # constrain to domain, if set
        diff = end - start
        if @options.constrain && start < @options.domain.start
            start = @options.domain.start
            newEnd = new Date(start.getTime() + diff)
            end = if newEnd < @options.domain.end then newEnd else @options.domain.end
        if @options.constrain && end > @options.domain.end
            end = @options.domain.end
            newStart = new Date(end.getTime() - diff)
            start = if newStart > @options.domain.start then newStart else @options.domain.start

        # constrain to displayLimit
        if @options.displayLimit != null and (end - start) > @options.displayLimit * 1000
            start = offsetDate(end, -@options.displayLimit)

        @options.zoom.scale((@options.display.end - @options.display.start) / (end - start))
        @options.zoom.translate([ @options.zoom.translate()[0] - @scales.x(start), 0 ])
        @redraw()
        if doReload
            for dataset of @datasets
                @reloadDataset(dataset)
        true

    # zoom to start/end. redraws.
    zoom: (params...) ->
        start = new Date(params[0])
        end = new Date(params[1])
        [ start, end ] = [ end, start ] if end < start

        # constrain to domain, if set
        diff = end - start
        if @options.constrain && start < @options.domain.start
            start = @options.domain.start
            newEnd = new Date(start.getTime() + diff)
            end = if newEnd < @options.domain.end then newEnd else @options.domain.end
        if @options.constrain && end > @options.domain.end
            end = @options.domain.end
            newStart = new Date(end.getTime() - diff)
            start = if newStart > @options.domain.start then newStart else @options.domain.start

        # constrain to displayLimit
        if @options.displayLimit != null and (end - start) > @options.displayLimit * 1000
            start = offsetDate(end, -@options.displayLimit)

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
        .each('end', => @reloadDataset(dataset) for dataset of @datasets)
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

    setTooltipFormatter: (@tooltipFormatter) ->

    setBinTooltipFormatter: (@binTooltipFormatter) ->

    setHighlightInterval: (start, end, fillColor, strokeColor, outsideColor) ->
        if start and end
            @highlightInterval =
                start: start
                end: end
                fillColor: fillColor
                strokeColor: strokeColor
                outsideColor: outsideColor
        else
            @highlightInterval = null

        @redraw()

    setRecordHighlights: (datasetId, intervals = []) ->
        dataset = @datasets[datasetId]
        if dataset?
            dataset.setRecordHighlights(intervals)
            @redraw()

# Interface for a source
class Source
    fetch: (start, end, params, callback) ->

module.exports = TimeSlider
