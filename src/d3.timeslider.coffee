class TimeSlider

    # TODO
    #  * Implement a function to fetch dataset information from a WMS / WCS service
    #  * Compute the padding at the left & right of the timeslider
    #  * TESTING

    constructor: (@element, @options = {}) ->
        # Debugging?
        @debug = true

        # create the root svg element
        @svg = d3.select(element).append('svg').attr('class', 'timeslider')

        @useBBox = false;
        if(@svg[0][0].clientWidth == 0)
            d3.select(element).select('svg').append('rect').attr('width', '100%').attr('height', '100%').attr('opacity', '0')
            @useBBox = true

        # default options and other variables for later
        @options.width = if @useBBox then @svg[0][0].getBBox().width else @options.width  = @svg[0][0].clientWidth
        @options.height = if @useBBox then @svg[0][0].getBBox().height else @svg[0][0].clientHeight
        @options.brush ||= {}
        @options.brush.start || = @options.start
        @options.brush.end ||= new Date(new Date(@options.brush.start).setDate(@options.brush.start.getDate() + 3))

        # array to hold individual data points / data ranges
        @data = {}

        # create a custom formatter for labeling ticks
        customFormatter = (formats) =>
            (date) ->
                i = formats.length - 1
                f = formats[i]

                f = formats[i--] until f[1](date)
                f[0](date)

        customFormats = customFormatter([
            [d3.time.format("%Y"), -> true ],
            [d3.time.format("%B %Y"), (d) -> d.getUTCMonth() ],
            [d3.time.format("%b %d %Y"), (d) -> d.getUTCDate() != 1 ],
            [d3.time.format("%b %d %Y "), (d) ->d.getUTCDay() && d.getUTCDate() != 1 ],
            [d3.time.format("%I %p"), (d) -> d.getUTCHours() ],
            [d3.time.format("%I:%M"), (d) -> d.getUTCMinutes() ],
            [d3.time.format(":%S"), (d) -> d.getUTCSeconds() ],
            [d3.time.format(".%L"), (d) -> d.getUTCMilliseconds() ]
        ])

        # scales
        @scales =
            x: d3.time.scale.utc()
                .domain([ @options.domain.start, @options.domain.end ])
                .range([0, @options.width])
                .nice()

        # axis
        @axis =
            x: d3.svg.axis()
                .scale(@scales.x)
                .innerTickSize(@options.height - 13)
                .tickFormat(customFormats)

        @svg.append('g')
            .attr('class', 'axis')
            .call(@axis.x)

        # translate the main x axis
        d3.select(@element).select('g.axis .domain')
            .attr('transform', "translate(0, #{options.height - 18})")

        # brush
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
                    .on('zoom', zoom)
                element.dispatchEvent(
                    new CustomEvent('selectionChanged', {
                        detail: {
                            start: @brush.extent()[0],
                            end: @brush.extent()[1]
                        }
                        bubbles: true,
                        cancelable: true
                    })
                )
            )
            .extent([@options.brush.start, @options.brush.end])

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
            @svg.select('g.datasets')
                .append('g')
                    .attr('class', 'dataset')
                    .attr('id', "dataset-#{dataset.id}")
            el = @svg.select("g.datasets #dataset-#{dataset.id}")
            @options.datasetIndex = 0 unless @options.datasetIndex?

            @data[dataset.id] = {
                index: @options.datasetIndex++,
                color: dataset.color,
                callback: dataset.data,
                points: [],
                ranges: []
            }

            @updateDataset(dataset.id)

        @updateDataset = (dataset) =>
            el = @svg.select("g.datasets #dataset-#{dataset}")
            d = @data[dataset]

            # update data
            d.ranges = []
            d.points = []

            for data in d.callback(@scales.x.domain()[0], @scales.x.domain()[1])
                if(data.length > 1)
                    d.ranges.push data
                else
                    d.points.push data[0]

            # ranges
            el.selectAll('path').remove()
            r = el.selectAll('path')
                .data(d.ranges)

            r.enter().append('path')
                .attr('d',
                    d3.svg.line()
                        .x( (d) => @scales.x(d) )
                        .y( -5 * d.index )
                        .interpolate('linear')
                    )
                .attr('stroke', d.color)

            r.exit().remove()

            # points
            el.selectAll('circle').remove()
            p = el.selectAll('circle')
                .data(d.points)
                .remove()

            p.enter().append('circle')
                    .attr('cx', (d) => @scales.x(d))
                    .attr('cy', "#{-5 * d.index}")
                    .attr('fill', d.color)
                    .attr('r', 2)

            p.exit().remove()

        for dataset in @options.datasets
            do (dataset) => @drawDataset(dataset)

        @redraw = =>
            # update brush
            @brush.x(@scales.x).extent(@brush.extent())

            # repaint the axis and the brush
            d3.select(@element).select('g.axis').call(@axis.x)
            d3.select(@element).select('g.brush').call(@brush)

            # repaint the datasets
            for dataset of @data
                @updateDataset(dataset)

        # resizing (the window)
        resize = =>
            # update the width of the element and the scales
            svg = d3.select(@element).select('svg.timeslider')[0][0]
            @options.width = if @useBBox then svg.getBBox().width else svg.clientWidth
            @scales.x.range([0, @options.width])

            @redraw()

        d3.select(window).on('resize', resize)

        # zooming & dragging
        zoom = =>
            @redraw()

        @options.zoom = d3.behavior.zoom()
            .x(@scales.x)
            .size([@options.width, @options.height])
            .scaleExtent([1, Infinity])
            .on('zoom', zoom)
        @svg.call(@options.zoom)

    # Function pair to allow for easy hiding and showing the time slider
    hide: ->
        @originalDisplay = @element.style.display
        @element.style.display = 'none'
        true

    show: ->
        @element.style.display = @originalDisplay
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
        return false unless params.length == 2

        start = new Date(params[0])
        end = new Date(params[1])
        [ start, end ] = [ end, start ] if end < start

        start = @options.start if start < @options.start
        end = @options.end if end > @options.end

        d3.select(@element).select('g.brush').call(@brush.extent([start, end]))
        @element.dispatchEvent(new CustomEvent('selectionChanged', {
            detail: {
                start: @brush.extent()[0],
                end: @brush.extent()[1]
            }
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
        delete @data[id]
        d3.select(@element).select("g.dataset#dataset-#{id}").remove()

        # repaint the datasets
        for dataset of @data
            @data[dataset].index -= 1 if @data[dataset].index > i
            @updateDataset(dataset)

        true

    # TODO
    center: (params...) ->
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

                # update brush
                @brush.x(@scales.x).extent(@brush.extent())

                # repaint the axis and the brush
                d3.select(@element).select('g.axis').call(@axis.x)
                d3.select(@element).select('g.brush').call(@brush)

                # repaint the datasets
                @updateDataset(dataset) for dataset of @data
        )

        true

    reset: ->
        @zoom(@options.domain.start, @options.domain.end)
        true

# Export the TimeSlider object for use in the browser
this.TimeSlider = TimeSlider
