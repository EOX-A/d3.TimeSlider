RecordDataset = require './record-dataset.coffee'
BucketCache = require '../caches/bucket-cache.coffee'

class BucketDataset extends RecordDataset
    constructor: (options) ->
        super(options)
        @bucketCache = new BucketCache()
        { @bucketSource } = options
        currentBucketSyncState = 0
        lastBucketSyncState = 0

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

        [ count, definite ] = @bucketCache.getTotalCount(resolution, start, end)

        if count > @histogramThreshold or not definite
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
            # for bucket in bucketsToFetch
            bucketsToFetch.forEach (bucket) =>
                @bucketCache.reserveBucket(resolution, bucket)
                a = new Date(bucket)
                b = new Date(bucket.getTime() + resolution)
                source(a, b, params, (count) =>
                    @bucketCache.setBucket(resolution, a, count)
                    fetched += 1
                    if bucketsToFetch.length == fetched and @currentBucketSyncState is @lastBucketSyncState
                        @listeners.synced()
                )

    draw: (start, end, options) ->
        { scales } = options
        [ ticks, resolution ] = @makeTicks(scales.x)
        [ count, definite ] = @bucketCache.getTotalCount(resolution, start, end)
        if count > @histogramThreshold or not definite
            # TODO: clean up records and histograms
            @element.selectAll('.record').remove()
            @element.selectAll('.bin').remove()
            @drawBuckets(ticks, resolution, options)
        else
            @element.selectAll('.bucket').remove()
            super(start, end, options)

    drawBuckets: (ticks, resolution, options) ->
        { scales, height } = options

        buckets = ticks.map((tick) =>
            [tick, @bucketCache.getBucket(resolution, tick) || 0]
        )

        y = d3.scale.linear()
          .domain([0, d3.max(buckets, (d) -> d[1])])
          .range([2, height - 29])
          .clamp(true)

        bars = @element.selectAll('.bucket')
          .data(buckets)

        bars.attr('class', 'bucket')
          .call((bucketElement) => @setupBucket(bucketElement, y, resolution, options))

        bars.enter().append('rect')
          .call((bucketElement) => @setupBucket(bucketElement, y, resolution, options))

        bars.exit().remove()

    setupBucket: (bucketElement, y, resolution, { scales, tooltip, binTooltipFormatter }) ->
        bucketElement
            .attr('class', 'bucket')
            .attr('fill', @color)
            .attr('x', 1)
            .attr('width', (d) => scales.x(d[0].getTime() + resolution) - scales.x(d[0]) - 1)
            .attr('transform', (d) => "translate(#{ scales.x(new Date(d[0])) }, #{ -y(d[1]) })")
            .attr('height', (d) -> y(d[1]))

module.exports = BucketDataset
