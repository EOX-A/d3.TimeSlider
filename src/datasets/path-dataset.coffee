Dataset = require './dataset.coffee'

class PathDataset extends Dataset
    constructor: (options) ->
        super(options)

    draw: (start, end, options) ->
        { scales, axes, height } = options
        data = @records || @paths
        if data and data.length
            @drawPaths(data, scales, axes, height)

    drawPaths: (data, scales, axes, height) ->
        scales.y.domain(d3.extent(data, (d) -> d[1]))

        @element.selectAll('path').remove()
        @element.selectAll('.y.axis').remove()

        line = d3.svg.line()
            .x( (a) => scales.x(new Date(a[0])) )
            .y( (a) => scales.y(a[1]) )

        # TODO: Tests with clipping mask for better readability
        # element.attr('clip-path', 'url(#clip)')

        # clippath = element.append('defs').append('svg:clipPath')
        #     .attr('id', 'clip')

        # element.select('#clip').append('svg:rect')
        #         .attr('id', 'clip-rect')
        #         .attr('x', (options.index+1)*30)
        #         .attr('y', -@options.height)
        #         .attr('width', 100)
        #         .attr('height', 100)

        @element.append('path')
            #.attr('clip-path', 'url(#clip)')
            .datum(data)
            .attr('class', 'line')
            .attr('d', line)
            .attr('stroke', @color)
            .attr('stroke-width', '1.5px')
            .attr('fill', 'none')
            .attr('transform', "translate(0, #{ -height + 29 })")


        step = (scales.y.domain()[1] - scales.y.domain()[0])/4
        axes.y.tickValues(
            d3.range(scales.y.domain()[0], scales.y.domain()[1]+step, step)
        )

        @element.append('g')
            .attr('class', 'y axis')
            .attr('fill', @color)
            .call(axes.y)
            .attr('transform', "translate(#{ (@index + 1) * 30 }, #{ -height + 29 })")

        @element.selectAll('.axis .domain')
            .attr('stroke-width', '1')
            .attr('stroke', @color)
            .attr('shape-rendering', 'crispEdges')
            .attr('fill', 'none')

        @element.selectAll('.axis line')
            .attr('stroke-width', '1')
            .attr('shape-rendering', 'crispEdges')
            .attr('stroke', @color)

        @element.selectAll('.axis path')
            .attr('stroke-width', '1')
            .attr('shape-rendering', 'crispEdges')
            .attr('stroke', @color)

module.exports = PathDataset
