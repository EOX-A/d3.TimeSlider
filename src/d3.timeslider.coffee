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
        @brushTooltipOffset = [30, 20];

        @tooltip = d3.select("body").append("div")   
            .attr("class", "tooltip")               
            .style("opacity", 0);

        @tooltipBrushMin = d3.select("body").append("div")   
            .attr("class", "tooltip")               
            .style("opacity", 0);
        @tooltipBrushMax = d3.select("body").append("div")   
            .attr("class", "tooltip")               
            .style("opacity", 0);

        # used for show()/hide()
        @originalDisplay = @element.style.display

        # create the root svg element
        @svg = d3.select(element).append('svg')
            .attr('class', 'timeslider')


        # TODO: what does this do???

        @useBBox = false;
        if @svg[0][0].clientWidth == 0
            d3.select(element).select('svg')
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
        @options.brush.start || = @options.start
        @options.brush.end ||= new Date(new Date(@options.brush.start).setDate(@options.brush.start.getDate() + 3))
        @options.debounce ||= 50
        @options.ticksize ||= 3
        @options.datasets ||= []

        # object to hold individual data points / data ranges
        @datasets = {}

        @timetickDate = false;
        @simplifyDate = d3.time.format("%d.%m.%Y - %H:%M:%S")

        # debounce function for rate limiting
        # TODO: find a better solution
        @timeouts = []
        debounce = (timeout, id, fn) =>
            return unless timeout and id and fn
            @timeouts[id] = -1 unless @timeouts[id]

            return =>
                window.clearTimeout(@timeouts[id]) if @timeouts[id] > -1
                @timeouts[id] = window.setTimeout(fn, timeout)

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
                    .on('zoom', zoom)
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
                        .style("opacity", 0);

                    @tooltipBrushMax.transition()
                        .duration(100)
                        .style("opacity", 0);

            )
            .on('brush', =>
                if (@brushTooltip)
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
                        .style("opacity", .9);
                    @tooltipBrushMin.html(@simplifyDate(@brush.extent()[0]))
                        .style("left", (@scales.x(@brush.extent()[0])+@brushTooltipOffset[0]) + "px")
                        .style("top", (offheight + @brushTooltipOffset[1]) + "px");


                    @tooltipBrushMax.transition()
                        .duration(100)
                        .style("opacity", .9);
                    @tooltipBrushMax.html(@simplifyDate(@brush.extent()[1]))
                        .style("left", (@scales.x(@brush.extent()[1])+@brushTooltipOffset[0]) + "px")
                        .style("top", (offheight + @brushTooltipOffset[1] + 20) + "px");

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
            .attr('transform', "translate(0, #{options.height - 23})")

        # initialize all datasets
        for dataset in @options.datasets
            do (dataset) => @drawDataset(dataset)

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
                @updateDataset(dataset)

        # Afterwards paint lines so they are not overlapped
        for dataset of @datasets
            if @datasets[dataset].lineplot
                @reloadDataset(dataset)
                @updateDataset(dataset)

        # repaint timetick
        @drawTimetick() 

    drawTimetick: ->
        @svg.selectAll('.timetick').remove()



        # TODO: @timetickDate seems to be set nowhere, so this is obviously never called???


        if (Object.prototype.toString.call(@timetickDate) == '[object Date]')

            r = @svg.selectAll('.timetick')
                .data([@timetickDate])
            
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
        

    drawRanges: (datasetElement, data, options) ->

        datasetElement.selectAll('rect').remove()

        r = datasetElement.selectAll('rect')
            .data(data)
        
        r.enter().append('rect')
            .attr('x', (a) => @scales.x(new Date(a[0])) )
            .attr('y', - (@options.ticksize + 3) * options.index + -(@options.ticksize-2) )
            .attr('width', (a) => (@scales.x(new Date(a[1])) - @scales.x(new Date(a[0]))) )
            .attr('height', (@options.ticksize-2))
            .attr('stroke', d3.rgb(options.color).darker())
            .attr('stroke-width', 1)
            .attr('fill', (a) =>
                if @recordFilter(a)
                    options.color
                else
                    "transparent"
            )
            .on("mouseover", (d) =>
                if (d[2])
                    @tooltip.transition()        
                        .duration(200)      
                        .style("opacity", .9);      
                    @tooltip.html(d[2])  
                        .style("left", (d3.event.pageX) + "px")     
                        .style("top", (d3.event.pageY - 28) + "px");    
            )                  
            .on("mouseout", (d) =>
                @tooltip.transition()        
                    .duration(500)      
                    .style("opacity", 0);   
            )
            .on('click', (d) =>
                @element.dispatchEvent(
                    new CustomEvent('coverageselected', {
                        detail: {
                            bbox: d[3],
                            start: d[0],
                            end:d[1]
                        }
                        bubbles: true,
                        cancelable: true
                    })
                )
            );

        r.exit().remove()

    drawPoints: (datasetElement, data, options) ->
        datasetElement.selectAll('circle').remove()
        p = datasetElement.selectAll('circle')
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
                    @tooltip.transition()        
                        .duration(200)      
                        .style("opacity", .9);      
                    @tooltip.html(d[2])  
                        .style("left", (d3.event.pageX) + "px")     
                        .style("top", (d3.event.pageY - 28) + "px");    
                )                  
            .on("mouseout", (d) =>
                @tooltip.transition()        
                    .duration(500)      
                    .style("opacity", 0);   
            ).on('click', (d) =>
                @element.dispatchEvent(
                    new CustomEvent('coverageselected', {
                        detail: {
                            bbox: d[3],
                            start: d[0],
                            end:d[1]
                        }
                        bubbles: true,
                        cancelable: true
                    })
                )
            );

        p.exit().remove()

    drawPaths: (datasetElement, data, options) ->
        @scales.y.domain(d3.extent(data, (d) => d[1]));

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
            .attr('stroke', options.color)
            .attr('stroke-width', "1.5px")
            .attr('fill', 'none')
            .attr('transform', "translate(0,"+ (-@options.height+29)+")")

        
        step = (@scales.y.domain()[1] - @scales.y.domain()[0])/4
        @axis.y.tickValues(
            d3.range(@scales.y.domain()[0],@scales.y.domain()[1]+step, step)
        )

        datasetElement.append("g")
            .attr("class", "y axis")
            .attr('fill', options.color)
            .call(@axis.y)
            .attr("transform", "translate("+((options.index+1)*30)+","+ (-@options.height+29)+")")

        datasetElement.selectAll('.axis .domain')
            .attr("stroke-width", "1")
            .attr("stroke", options.color)
            .attr("shape-rendering", "crispEdges")
            .attr("fill", "none");

        datasetElement.selectAll('.axis line')
            .attr("stroke-width", "1")
            .attr("shape-rendering", "crispEdges")
            .attr("stroke", options.color);

        datasetElement.selectAll('.axis path')
            .attr("stroke-width", "1")
            .attr("shape-rendering", "crispEdges")
            .attr("stroke", options.color);


    # this function does *not* draw datasets, but instead initializes the 
    # elements and triggers a reload

    # TODO: rename
    # TODO: figure out

    drawDataset: (dataset) ->
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


        @datasets[dataset.id] = {
            index: index,
            color: dataset.color,
            callback: dataset.data,
            points: [],
            ranges: [],
            lineplot: lineplot
        }
        
        @reloadDataset(dataset.id)


    # this function acually draws a dataset

    updateDataset: (datasetId) ->
        datasetElement = @svg.select("g.datasets #dataset-#{dataset}")
        d = @datasets[datasetId]

        points = d.ranges.filter((values) => (@scales.x(new Date(values[1])) - @scales.x(new Date(values[0]))) < 5)#.map((values) => values[0])
        ranges = d.ranges.filter((values) => (@scales.x(new Date(values[1])) - @scales.x(new Date(values[0]))) >= 5)

        if(d.paths && d.paths.length>0)
            drawPaths(datasetElement, d.paths, { index: d.index, color: d.color })
        else
            drawRanges(datasetElement, ranges, { index: d.index, color: d.color })
            drawPoints(datasetElement, points.concat(d.points), { index: d.index, color: d.color })

    # this function triggers the reloading of a dataset (sync)

    reloadDataset: (datasetId) ->
        callback = debounce(@options.debounce, datasetId, =>
            @datasets[datasetId].callback(@scales.x.domain()[0], @scales.x.domain()[1], (id, data) =>
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

                @datasets[id].ranges = ranges
                @datasets[id].points = points
                @datasets[id].paths = paths
                @updateDataset(id)
            , @bbox)
        )
        callback()

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
    addDataset: (dataset) ->
        @drawDataset(dataset)
        true

    # remove a dataset. redraws.
    removeDataset: (id) ->
        return false unless @datasets[id]?

        i = @datasets[id].index
        lp = @datasets[id].lineplot
        delete @datasets[id]

        if lp
            @options.linegraphIndex--
        else
            @options.datasetIndex--
        
        d3.select(@element).select("g.dataset#dataset-#{id}").remove()

        for dataset of @datasets
            if lp == @datasets[dataset].lineplot
                @datasets[dataset].index -= 1 if @datasets[dataset].index > i

        @redraw()
        true

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



class Dataset
    constructor: (@id, @color, @source, @sourceParams) ->

    getSource: ->
        @source

    setSource: (@source) ->

    sync: (start, end, callback) ->
        @source.fetch start, end, @sourceParams, (records) =>
            callback(records)


# Interface for a source
class Source
    fetch: (start, end, params, callback) ->


module.exports = TimeSlider


