RecordDataset = require './record-dataset.coffee'
BucketCache = require '../caches/bucket-cache.coffee'
{ after, centerTooltipOn, intersects } = require '../utils.coffee'

class BucketDataset extends RecordDataset
    constructor: (options) ->
        super(options)
        @bucketCache = new BucketCache()
        { @bucketSource } = options
        currentBucketSyncState = 0
        lastBucketSyncState = 0
        @toFetch = 0

    useBuckets: (start, end, preferRecords = false) ->
        [ isLower, definite ] = @bucketCache.isCountLower(start, end, @histogramThreshold, preferRecords)

        if preferRecords and not definite
            count = @cache.get(start, end).length
            if count > 0 and count < @histogramThreshold
                return true

        return not isLower or not definite

    makeTicks: (scale) ->
        ticks = scale.ticks(@histogramBinCount or 20)
        resolution = d3.median(
            (ticks[i] - ticks[i-1] for i in [1..(ticks.length-1)])
        )
        ticks = [new Date(ticks[0].getTime() - resolution)]
            .concat(ticks)
            .concat([new Date(ticks[ticks.length - 1].getTime() + resolution)])
        return [ticks, resolution];

    isSyncing: () ->
        return @toFetch > 0

    doFetch: (start, end, params) ->
        { scales } = params
        [ ticks, resolution ] = @makeTicks(scales.x)

        [ isLower, definite ] = @bucketCache.isCountLower(start, end, @histogramThreshold)

        if @useBuckets(start, end)
            @doFetchBuckets(start, end, resolution, ticks, params)
        else
            super(start, end, params)

    doFetchBuckets: (start, end, resolution, ticks, params) ->
        source = @getSourceFunction(@bucketSource)
        bucketsToFetch = []
        for tick, i in ticks
            if not @bucketCache.hasBucketOrReserved(resolution, tick)
                next = ticks[i + 1]
                dt = next.getTime() - tick.getTime() if next
                bucketsToFetch.push([tick, dt])

        if bucketsToFetch.length > 0
            @toFetch += bucketsToFetch.length
            @listeners.syncing()

            summaryCallback = after(bucketsToFetch.length, () =>
                if not @useBuckets(start, end)
                    RecordDataset.prototype.doFetch.call(this, start, end, params)
            )

            bucketsToFetch.forEach ([bucket, dt]) =>
                @bucketCache.reserveBucket(resolution, bucket)
                a = new Date(bucket)
                b = new Date(bucket.getTime() + (dt or resolution))
                source(a, b, params, (count) =>
                    @bucketCache.setBucket(resolution, a, dt, count)
                    @toFetch -= 1
                    @listeners.synced()
                    summaryCallback()
                )

    draw: (start, end, options) ->
        if @useBuckets(start, end, true)
            { scales } = options
            [ ticks, resolution ] = @makeTicks(scales.x)
            @element.selectAll('.record').remove()
            @element.selectAll('.bin').remove()
            @drawBuckets(ticks, resolution, options)
        else
            @element.selectAll('.bucket').remove()
            super(start, end, options)

    drawBuckets: (ticks, resolution, options) ->
        { scales, height } = options

        buckets = ticks.map((tick) =>
            [ bucket, definite ] = @bucketCache.getBucketApproximate(resolution, tick)
            end = new Date(tick.getTime() + bucket.width) if bucket.width?
            return [ tick, end, bucket.count, definite ]
        )

        y = d3.scale.linear()
          .domain([0, d3.max(buckets, (d) -> d[2])])
          .range([2, height - 29])
          .clamp(true)

        bars = @element.selectAll('.bucket')
          .data(buckets)

        bars.attr('class', 'bucket')
          .call((bucketElement) =>
              @setupBuckets(bucketElement, y, resolution, options)
          )

        bars.enter().append('rect')
          .call((bucketElement) =>
              @setupBuckets(bucketElement, y, resolution, options)
          )

        bars.exit().remove()

        missingIntervals = buckets
            .filter((bucket) -> not bucket[3])
            .map((bucket) ->
                if bucket[1]
                    return bucket
                else
                    return [bucket[0], new Date(bucket[0].getTime() + resolution)]
            )

        @drawMissing(missingIntervals, true, scales, options)

    setupBuckets: (bucketElement, y, resolution, { scales, tooltip, binTooltipFormatter }) ->
        bucketElement
            .attr('class', 'bucket')
            .attr('fill', (d) =>
                interval = [d[0], d[1] or new Date(d[0].getTime() + resolution)]
                highlight = @recordHighlights.reduce((acc, int) =>
                    acc || intersects(int, interval)
                , false)
                if highlight
                    @highlightFillColor
                else
                    @color
            )
            .attr('stroke', (d) =>
                interval = [d[0], d[1] or new Date(d[0].getTime() + resolution)]
                highlight = @recordHighlights.reduce((acc, int) =>
                    acc || intersects(int, interval)
                , false)
                if highlight
                    @highlightStrokeColor
                else if @noBorder
                    d3.rgb(@color)
                else
                    d3.rgb(@color).darker()
            )
            .attr('fill-opacity', (d) -> if d[2] then 1 else 0.5)
            .attr('x', 1)
            .attr('width', (d) =>
                scales.x((d[1] or new Date(d[0].getTime() + resolution))) - scales.x(d[0]) - 1
            )
            .attr('transform', (d) =>
                "translate(#{ scales.x(d[0]) }, #{ -y(d[2]) or 0 })"
                )
            .attr('height', (d) -> if d[2] then y(d[2]) else 0)
            .attr('stroke-width', if @noBorder then 2 else 1)

        bucketElement
            .on('mouseover', (bucket) =>
                @dispatch('bucketMouseover', {
                    dataset: @id,
                    start: bucket[0],
                    end: bucket[1] || new Date(bucket[0].getTime() + resolution),
                    count: bucket[2]
                })

                if bucket
                    message = "#{ bucket[2] if bucket[2]? }"
                    if message.length
                        tooltip.html(message)
                            .transition()
                            .duration(200)
                            .style('opacity', .9)
                        centerTooltipOn(tooltip, d3.event.target)
            )
            .on('mouseout', (bucket) =>
                @dispatch('bucketMouseout', {
                    dataset: @id,
                    start: bucket[0],
                    end: bucket[1] || new Date(bucket[0].getTime() + resolution),
                    count: bucket[2]
                })
                tooltip.transition()
                    .duration(500)
                    .style('opacity', 0)
            )
            .on('click', (bucket) =>
                @dispatch('bucketClicked', {
                    dataset: @id,
                    start: bucket[0],
                    end: bucket[1] || new Date(bucket[0].getTime() + resolution),
                    count: bucket[2]
                })
            )

    clearCaches: () ->
        @cache.clear() if @cache
        @bucketCache.clear() if @bucketCache

module.exports = BucketDataset
