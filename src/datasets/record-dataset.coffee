Dataset = require './dataset.coffee'
RecordCache = require '../caches/record-cache.coffee'
{ centerTooltipOn, split, intersects } = require '../utils.coffee'


class RecordDataset extends Dataset
    constructor: (options) ->
        { @histogramThreshold, @histogramBinCount, @cluster } = options
        { cacheIdField, cacheRecords } = options
        @cache = new RecordCache(cacheIdField) if cacheRecords
        super(options)

    # assures the correct layout of the records; [ date, date [, params ] ]
    postprocess: (records) ->
        return records.map((record) ->
            if record instanceof Date
                record = [ record, record ]

            else if not (record[1] instanceof Date)
                record = [ record[0], record[0] ].concat(record[1..])

            return record
        )

    draw: (start, end, options) ->
        { scales } = options
        if not @records or not @records.length
            return

        interval = [start, end]
        records = @records.filter((record) -> intersects(record, interval))

        if @histogramThreshold? and records.length >= @histogramThreshold
            @element.selectAll('.record').remove()
            data = records.map((record) =>
                new Date(record[0] + (record[1] - record[0]) / 2)
            )
            @drawHistogram(records, scales, options)

        else
            @element.selectAll('.bin').remove()
            x = scales.x
            if @cluster
                reducer = (args...) => @clusterReducer(args..., x)
                records = records
                    .reduce(reducer, [])
                    .map((r) -> if r.cluster then r else [r[0], r[1], r[2][0][2]])

            [points, ranges] = split(records, (r) => @drawAsPoint(r, x))

            @drawRanges(ranges, scales, options)
            @drawPoints(points, scales, options)

    drawAsPoint: (record, scale) ->
        return (scale(record[1]) - scale(record[0])) < 5

    clusterReducer = (acc, current, index, x) =>
        if @drawAsPoint(current, x)
            [intersecting, nonIntersecting] = split(acc, (b) ->
                distance(current, b, x) <= 5
            )
        else
            [intersecting, nonIntersecting] = split(acc, (b) ->
                intersects(current, b)
            )
        if intersecting.length
            newBin = [
              new Date(d3.min(intersecting, (b) -> b[0])),
              new Date(d3.max(intersecting, (b) -> b[1])),
              intersecting.map((b) -> b[2]).reduce(((a, r) -> a.concat(r)), [])
            ]
            newBin[0] = current[0] if current[0] < newBin[0]
            newBin[1] = current[1] if current[1] > newBin[1]
            newBin[2].push(current)
            newBin.cluster = true
            nonIntersecting.push(newBin)
            return nonIntersecting
        else
            acc.push([current[0], current[1], [current]])
        return acc

    drawRanges: (records, scales, options) ->
        { ticksize } = options
        rect = (elem) =>
            elem.attr('class', 'record')
                .attr('x', (record) => scales.x(new Date(record[0])) )
                .attr('y', - (ticksize + 3) * @index + -(ticksize - 2) )
                .attr('width', (record) =>
                    scales.x(new Date(record[1])) - scales.x(new Date(record[0]))
                )
                .attr('height', (ticksize - 2))
                .attr('stroke', d3.rgb(@color).darker())
                .attr('stroke-width', 1)

        r = @element.selectAll('rect.record')
            .data(records)
            .call(rect)

        r.enter().append('rect')
            .call(rect)
            .call((recordElement) => @setupRecord(recordElement, options))

        r.exit().remove()

    drawPoints: (records, scales, options) ->
        { ticksize } = options
        circle = (elem) =>
            elem.attr('class', 'record')
                .attr('cx', (a) =>
                    if Array.isArray(a)
                        if a[0] != a[1]
                            return scales.x(new Date(a[0].getTime() + Math.abs(a[1] - a[0]) / 2))
                        return scales.x(new Date(a[0]))
                    else
                        return scales.x(new Date(a))
                )
                .attr('cy', - (ticksize + 3) * @index - (ticksize - 2) / 2)
                .attr('stroke', d3.rgb(@color).darker())
                .attr('stroke-width', 1)
                .attr('r', ticksize / 2)

        p = @element.selectAll('circle.record')
            .data(records)
            .call(circle)

        p.enter().append('circle')
            .call(circle)
            .call((recordElement) => @setupRecord(recordElement, options))

        p.exit().remove()

    drawHistogram: (records, scales, height) ->
        ticks = scales.x.ticks(@histogramBinCount or 20)
        dx = ticks[1] - ticks[0]
        ticks = [new Date(ticks[0].getTime() - dx)]
            .concat(ticks)
            .concat([new Date(ticks[ticks.length - 1].getTime() + dx)])

        bins = d3.layout.histogram()
          .bins(ticks)
          .range(scales.x.domain())
          .value((record) -> new Date(record[0] + (record[1] - record[0]) / 2))(records)
          .filter((b) -> b.length)

        y = d3.scale.linear()
          .domain([0, d3.max(bins, (d) -> d.length)])
          .range([2, height - 29])
          .clamp(true)

        bars = @element.selectAll('.bin')
          .data(bins)

        bars.attr('class', 'bin')
          .call((binElement) => @setupBin(binElement, y, options))

        bars.enter().append('rect')
          .call((binElement) => @setupBin(binElement, y, options))

        bars.exit().remove()

    # Convenience method to hook up a single record elements events
    setupRecord: (recordElement, { recordFilter, tooltip, tooltipFormatter, binTooltipFormatter }) ->
        recordElement
            .attr('fill', (record) =>
                if not @recordFilter or recordFilter(record, this)
                    @color
                else
                    'transparent'
            )
            .on('mouseover', (record) =>
                if record.cluster
                    @dispatch('clusterMouseover', {
                        dataset: @id,
                        start: record[0],
                        end: record[1],
                        records: record[2]
                    })
                    message = binTooltipFormatter(record[2], this)
                else
                    @dispatch('recordMouseover', {
                        dataset: @id,
                        start: record[0],
                        end: record[1],
                        params: record[2]
                    })
                    message = tooltipFormatter(record, this)

                if message
                    tooltip.html(message)
                        .transition()
                        .duration(200)
                        .style('opacity', .9)
                    centerTooltipOn(tooltip, d3.event.target)
            )
            .on('mouseout', (record) =>
                if record.cluster
                    @dispatch('clusterMouseout', {
                        dataset: @id,
                        start: record[0],
                        end: record[1],
                        records: record[2]
                    })
                else
                    @dispatch('recordMouseout', {
                        dataset: @id,
                        start: record[0],
                        end: record[1],
                        params: record[2]
                    })
                tooltip.transition()
                    .duration(500)
                    .style('opacity', 0)
            )
            .on('click', (record) =>
                if record.cluster
                    @dispatch('clusterClicked', {
                        dataset: @id,
                        start: record[0],
                        end: record[1],
                        records: record[2]
                    })
                else
                    @dispatch('recordClicked', {
                        dataset: @id,
                        start: record[0],
                        end: record[1],
                        params: record[2]
                    })
            )

    setupBin: (binElement, y, { scales, tooltip, binTooltipFormatter }) ->
        binElement
            .attr('class', 'bin')
            .attr('fill', @color)
            .attr('x', 1)
            .attr('width', (d) => scales.x(d.x.getTime() + d.dx) - scales.x(d.x) - 1)
            .attr('transform', (d) => "translate(#{ scales.x(new Date(d.x)) }, #{ -y(d.length) })")
            .attr('height', (d) -> y(d.length))

        binElement
            .on('mouseover', (bin) =>
                @dispatch('binMouseover', {
                    dataset: @id,
                    start: bin.x,
                    end: new Date(bin.x.getTime() + bin.dx),
                    bin: bin
                })

                if bin.length
                    message = binTooltipFormatter(bin)
                    if message.length
                        tooltip.html(message)
                            .transition()
                            .duration(200)
                            .style('opacity', .9)
                        centerTooltipOn(tooltip, d3.event.target)
            )
            .on('mouseout', (bin) =>
                @dispatch('binMouseout', {
                    dataset: @id,
                    start: bin.x,
                    end: new Date(bin.x.getTime() + bin.dx),
                    bin: bin
                })
                tooltip.transition()
                    .duration(500)
                    .style('opacity', 0)
            )
            .on('click', (bin) =>
                @dispatch('binClicked', {
                    dataset: @id,
                    start: bin.x,
                    end: new Date(bin.x.getTime() + bin.dx),
                    bin: bin
                })
            )

module.exports = RecordDataset
