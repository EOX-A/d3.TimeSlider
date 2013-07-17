class TimeSlider

    # TODO
    #  * Allow for the registration of datasets to be shown beneath the brush
    #    * WCS  DescribeEOCoverageSet (using libcoveragejs (schindlerf))
    #  * Rename pixelPerDay to something more generic (could also be hours, ... depending on the time frame)
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
        @options.minPixelPerDay ||= 50
        @options.width  = svg[0][0].clientWidth
        @options.height = svg[0][0].clientHeight
        @options.brush ||= {}
        @options.brush.start || = @options.start
        @options.brush.end ||= new Date(new Date(@options.brush.start).setDate(@options.brush.start.getDate() + 3))
        # compute the number of days, (end - start / milliseconds per day)
        @options.numberOfDays = Math.ceil( (@options.end.getTime() - @options.start.getTime()) / (1000 * 60 * 60 * 24) )
        @element.zoomLevel = 0

        @options.pixelPerDay = @options.width / @options.numberOfDays
        @options.pixelPerDay = @options.minPixelPerDay if @options.pixelPerDay < @options.minPixelPerDay

        # array to hold individual data points / data ranges
        @data = {}

        # scales
        @scales =
            x: d3.time.scale.utc()
                .domain([ @options.start, @options.end ])
                .range([0, @options.width])
            y: d3.scale.linear()
                .range([ 0, @options.height ])

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

        # datasets
        @root.append('g')
            .attr('class', 'datasets')
            .attr('width', @options.width)
            .attr('height', @options.height)
            .attr('transform', "translate(0, 5)")

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
            console.log "Updating dataset #{dataset}"

            el = @root.select("g.datasets #dataset-#{dataset}")
            d = @data[dataset]

            # update data
            d.ranges = []
            d.points = []
            for data in d.callback()
                if(data.length > 1)
                    d.ranges.push data
                else
                    d.points.push data[0]

            lineFunction = d3.svg.line()
                .x( (d) => @scales.x(d) )
                .y( 5 * d.index )
                .interpolate('linear')

            # ranges
            el.selectAll('path').remove()
            r = el.selectAll('path')
                .data(d.ranges)

            r.enter().append('path')
                .attr('d', lineFunction)
                .attr('stroke', d.color)
                .attr('stroke-width', 2)

            r.exit().remove()

            # points
            el.selectAll('circle').remove()
            p = el.selectAll('circle')
                .data(d.points)
                .remove()

            p.enter().append('circle')
                    .attr('cx', (d) => @scales.x(d))
                    .attr('cy', "#{5 * d.index}")
                    .attr('r', 2)
                    .attr('fill', d.color)

            p.exit().remove()

        for dataset, index in @options.datasets
            do (dataset, index) ->
                drawDataset(dataset, index)

        # brush
        event = =>
            new CustomEvent('selectionChanged', {
                detail: {
                    start: @brush.extent()[0],
                    end: @brush.extent()[1]
                }
                bubbles: true,
                cancelable: true
            })
        @brush = d3.svg.brush()
            .x(@scales.x)
            .on('brushend', => element.dispatchEvent(event()))
            .extent([@options.brush.start, @options.brush.end])

        @root.append('g')
            .attr('class', 'brush')
            .call(@brush)
            .selectAll('rect')
                .attr('height', "#{@options.height - 15}")
                .attr('y', 0)

        # dragging
        drag = =>
            # init
            element.dragging = { position: [0, 0] } unless element.dragging

            # set last position of the curser
            element.dragging.lastPosition = [d3.event.pageX, d3.event.pageY]

            # register event handlers for mousemove (to handle the real dragging logic) and mouseup
            # to deregister unneeded handlers
            move = =>
                element.dragging.position[0] += d3.event.pageX - element.dragging.lastPosition[0]
                element.dragging.position[1] += d3.event.pageY - element.dragging.lastPosition[1]
                element.dragging.lastPosition = [d3.event.pageX, d3.event.pageY]

                # TODO Allow dragging over the boundaries, but snap back afterwards
                if element.dragging.position[0] > 0
                    element.dragging.position[0] = 0
                else if ((Number) element.dragging.position[0] + @scales.x.range()[1]) < @options.width
                    element.dragging.position[0] = @options.width - @scales.x.range()[1]
                @root.attr('transform', "translate(#{element.dragging.position[0]}, 0)")
            up = =>
                d3.select(document)
                    .on('mousemove', null)
                    .on('mouseup', null)

            d3.select(document)
                .on('mousemove', => move())
                .on('mouseup', => up())

            # prevent default events
            d3.event.preventDefault()
            d3.event.stopPropagation()

        d3.select(element).on('mousedown', drag)

        # resizing (the window)
        resize = =>
            # update the width of the element
            @options.width = d3.select(@element).select('svg.timeslider')[0][0].clientWidth

            # calculate new size of a day
            @options.pixelPerDay = (@options.width - 20) / @options.numberOfDays
            @options.pixelPerDay = @options.minPixelPerDay if @options.pixelPerDay < @options.minPixelPerDay

            # update scale
            @scales.x.range([0, @options.numberOfDays * @options.pixelPerDay])

            # update brush
            @brush.x(@scales.x).extent(@brush.extent())

            # repaint the axis, scales and the brush
            d3.select(@element).select('g.axis').call(@axis.x)
            d3.select(@element).select('g.brush').call(@brush)

        d3.select(window).on('resize', resize)

        # zooming
        zoom = =>
            console.log "Scale #{d3.event.scale}, Translate #{d3.event.translate}"

            # update axis & grids


            # repaint the datasets
            for dataset of @data
                @updateDataset(dataset)

            # repaint the scales and the axis
            d3.select(@element).select('g.axis').call(@axis.x)
            d3.select(@element).select('g.brush').call(@brush)

        @root.call(d3.behavior.zoom().x(@scales.x).on('zoom', zoom))

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
