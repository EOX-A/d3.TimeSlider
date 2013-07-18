class TimeSlider

    # TODO
    #  * Allow for the registration of datasets to be shown beneath the brush
    #    * WCS  DescribeEOCoverageSet (using libcoveragejs (schindlerf))
    #  * Cleanup the mess that is the axis labels right now
    #  * Compute the padding at the left & right of the timeslider
    #  * Convert all dates to UTC
    #  * TESTING

    constructor: (@element, @options = {}) ->
        # Debugging?
        @debug = true

        # create the root svg element
        svg = d3.select(element).append('svg').attr('class', 'timeslider')
        @root = svg.append('g').attr('class', 'root')

        # default options and other variables for later
        @options.width  = svg[0][0].clientWidth
        @options.height = svg[0][0].clientHeight
        @options.brush ||= {}
        @options.brush.start || = @options.start
        @options.brush.end ||= new Date(new Date(@options.brush.start).setDate(@options.brush.start.getDate() + 3))

        # array to hold individual data points / data ranges
        @data = {}

        # scales
        @scales =
            x: d3.time.scale.utc()
                .domain([ @options.start, @options.end ])
                .range([0, @options.width])

        # axis
        @axis =
            x: d3.svg.axis()
                .scale(@scales.x)
                .tickSubdivide(3)
                .tickSize(@options.height - 13)

        @root.append('g')
            .attr('class', 'axis')
            .call(@axis.x)

        # translate the main x axis
        d3.select(@element).select('g.axis .domain')
            .attr('transform', "translate(0, #{options.height - 13})scale(1, -1)")

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

        @root.append('g')
            .attr('class', 'brush')
            .call(@brush)
            .selectAll('rect')
                .attr('height', "#{@options.height - 15}")
                .attr('y', 0)

        # datasets
        @root.append('g')
            .attr('class', 'datasets')
            .attr('width', @options.width)
            .attr('height', @options.height)
            .attr('transform', "translate(0, #{options.height - 18})")

        drawDataset = (dataset, index) =>
            @root.select('g.datasets')
                .append('g')
                    .attr('class', 'dataset')
                    .attr('id', "dataset-#{dataset.id}")
            el = @root.select("g.datasets #dataset-#{dataset.id}")

            @data[dataset.id] = {
                index: index,
                color: dataset.color,
                callback: dataset.data,
                points: [],
                ranges: []
            }

            @updateDataset(dataset.id)

        @updateDataset = (dataset) =>
            el = @root.select("g.datasets #dataset-#{dataset}")
            d = @data[dataset]

            # update data
            d.ranges = []
            d.points = []

            for data in d.callback(@scales.x.domain()[0], @scales.x.domain()[1])
                if(data.length > 1)
                    d.ranges.push data
                else
                    d.points.push data[0]

            lineFunction = d3.svg.line()
                .x( (d) => @scales.x(d) )
                .y( -5 * d.index )
                .interpolate('linear')

            # ranges
            el.selectAll('path').remove()
            r = el.selectAll('path')
                .data(d.ranges)

            r.enter().append('path')
                .attr('d', lineFunction)
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

        for dataset, index in @options.datasets
            do (dataset, index) ->
                drawDataset(dataset, index)

        redraw = =>
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
            @options.width = d3.select(@element).select('svg.timeslider')[0][0].clientWidth
            @scales.x.range([0, @options.width])

            redraw()

        d3.select(window).on('resize', resize)

        # zooming & dragging
        zoom = =>
            redraw()

        @options.zoom = d3.behavior.zoom()
            .x(@scales.x)
            .scaleExtent([1, Infinity])
            .on('zoom', zoom)
        @root.call(@options.zoom)

    # Function pair to allow for easy hiding and showing the time slider
    hide: ->
        @originalDisplay = @element.style.display
        @element.style.display = 'none'
        true

    show: ->
        @element.style.display = @originalDisplay
        true

    select: (params...) ->
        start = new Date(params[0])
        start = @options.start if start < @options.start

        end = new Date(params[1])
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

    center: ->
        extent = @brush.extent()
        center = -1 * (@scales.x(new Date((extent[0].getTime() + extent[1].getTime()) / 2)) - @options.width / 2)
        center = 0 if center > 0
        d3.select(@element)[0][0].dragging = { position: [center, 0] }

        @root.attr('transform', "translate(#{center}, 0)")
        true

# Export the TimeSlider object for use in the browser
this.TimeSlider = TimeSlider
