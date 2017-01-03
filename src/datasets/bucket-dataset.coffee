RecordDataset = require './record-dataset.coffee'
BucketCache = require '../caches/bucket-cache.coffee'
{ after, centerTooltipOn } = require '../utils.coffee'

class BucketDataset extends RecordDataset
    constructor: (options) ->
        super(options)
        @bucketCache = new BucketCache()
        { @bucketSource } = options
        currentBucketSyncState = 0
        lastBucketSyncState = 0

    useBuckets: (start, end) ->
        [ isLower, definite ] = @bucketCache.isCountLower(start, end, @histogramThreshold)
        return not isLower or not definite

    makeTicks: (scale) ->
        ticks = scale.ticks(@histogramBinCount or 20)
        resolution = ticks[1] - ticks[0]
        ticks = [new Date(ticks[0].getTime() - resolution)]
            .concat(ticks)
            .concat([new Date(ticks[ticks.length - 1].getTime() + resolution)])
        return [ticks, resolution];

    isSyncing: () ->
        return !(@lastSyncState is @currentSyncState) || !(@currentBucketSyncState is @lastBucketSyncState)

    doFetch: (start, end, params) ->
        # TODO: if below threshold -> do the usual fetching
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
        for tick in ticks
            if not @bucketCache.hasBucketOrReserved(resolution, tick)
                bucketsToFetch.push(tick)

        if bucketsToFetch.length > 0
            fetched = 0
            @listeners.syncing()

            summaryCallback = after(bucketsToFetch.length, () =>
                if not @useBuckets(start, end)
                    RecordDataset.prototype.doFetch.call(this, start, end, params)
            )

            bucketsToFetch.forEach (bucket) =>
                @bucketCache.reserveBucket(resolution, bucket)
                a = new Date(bucket)
                b = new Date(bucket.getTime() + resolution)
                source(a, b, params, (count) =>
                    @bucketCache.setBucket(resolution, a, count)
                    fetched += 1
                    # if bucketsToFetch.length == fetched and @currentBucketSyncState is @lastBucketSyncState
                    # if bucketsToFetch.length == fetched and @currentBucketSyncState is @lastBucketSyncState
                    @listeners.synced()
                    summaryCallback()
                )

    draw: (start, end, options) ->
        if @useBuckets(start, end)
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
            [ count, definite ] = @bucketCache.getBucketApproximate(resolution, tick)
            return [ tick, count, definite ]
        )

        y = d3.scale.linear()
          .domain([0, d3.max(buckets, (d) -> d[1])])
          .range([2, height - 29])
          .clamp(true)

        bars = @element.selectAll('.bucket')
          .data(buckets)

        bars.attr('class', 'bucket')
          .call((bucketElement) =>
              @setupBucket(bucketElement, y, resolution, options)
          )

        bars.enter().append('rect')
          .call((bucketElement) =>
              @setupBucket(bucketElement, y, resolution, options)
          )

        bars.exit().remove()

    setupBucket: (bucketElement, y, resolution, { scales, tooltip, binTooltipFormatter }) ->
        bucketElement
            .attr('class', 'bucket')
            .attr('fill', @color)
            .attr('fill-opacity', (d) -> if d[2] then 1 else 0.5)
            .attr('x', 1)
            .attr('width', (d) => scales.x(d[0].getTime() + resolution) - scales.x(d[0]) - 1)
            .attr('transform', (d) => "translate(#{ scales.x(new Date(d[0])) }, #{ -y(d[1]) })")
            .attr('height', (d) -> if d[1] then y(d[1]) else 0)

        bucketElement
            .on('mouseover', (bucket) =>
                @dispatch('bucketMouseover', {
                    dataset: @id,
                    start: bucket[0],
                    end: new Date(bucket[0].getTime() + resolution),
                    count: bucket[1]
                })

                if bucket
                    message = "#{ bucket[1] if bucket[1]? }"
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
                    end: new Date(bucket[0].getTime() + resolution),
                    count: bucket[1]
                })
                tooltip.transition()
                    .duration(500)
                    .style('opacity', 0)
            )
            .on('click', (bucket) =>
                @dispatch('bucketClicked', {
                    dataset: @id,
                    start: bucket[0],
                    end: new Date(bucket[0].getTime() + resolution),
                    count: bucket[1]
                })
            )

module.exports = BucketDataset
