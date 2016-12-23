{ insort, bisect } = require '../utils.coffee'

toTime = (date) ->
    if date?.getTime? then date.getTime() else date

class BucketCache
    constructor: () ->
        @resolutions = [] # sorted list of resolutions
        @cache = {}

    # low level API: getting/setting buckets
    getBucket: (resolution, offset) ->
        time = toTime(offset)
        return @cache[resolution]?.buckets[offset]

    hasBucket: (resolution, offset) ->
        time = toTime(offset)
        return @cache[resolution]?.buckets[offset]?

    setBucket: (resolution, offset, count) ->
        time = toTime(offset)
        @prepareResolution(resolution)
        @cache[resolution].buckets[offset] = count
        insort(@cache[resolution].offsets, offset)

    # bucket reservation API
    reserveBucket: (resolution, offset) ->
        time = toTime(offset)
        @prepareResolution(resolution)
        if not @hasBucket(resolution, offset)
            @cache[resolution].buckets[offset] = null

    isBucketReserved: (resolution, offset) ->
        time = toTime(offset)
        if @cache[resolution]?
            return @cache[resolution].buckets[offset] is null

    hasBucketOrReserved: (resolution, offset) ->
        time = toTime(offset)
        return @hasBucket(resolution, offset) or @isBucketReserved(resolution, offset)

    # get the
    getTotalCount: (resolution, start, end) ->
        d = end - start
        # TODO: get min resolution
        # usedResolution = null
        # for resolution in resolutions
        #     if resolution <= d
        #
        #     else
        #         return false
        if not @hasResolution(resolution)
            return [0, false]

        offsets = @cache[resolution].offsets
        lo = Math.max(0, bisect(offsets, start) - 1)
        hi = Math.min(offsets.length - 1, bisect(offsets, end))

        coversWhole = offsets[lo] <= start and offsets[hi] >= end
        count = 0
        for offset in offsets[lo..hi]
            count += @getBucket(resolution, offset)

        return [count, coversWhole]

    hasResolution: (resolution) ->
        return @cache[resolution]?

    prepareResolution: (resolution) ->
        if not @hasResolution(resolution)
            @cache[resolution] = {
                buckets: {},
                offsets: []
            }
            insort(@resolutions, resolution)

module.exports = BucketCache
