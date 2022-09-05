{ insort, bisect } = require '../utils.coffee'

# convert a date to milliseconds
toTime = (date) ->
    if date?.getTime? then date.getTime() else date

# check if a list of offsets completely covers an interval
covers = (start, end, offsets, resolution) ->
    # check for empty list
    if offsets.length is 0
        return false

    last = offsets[offsets.length-1]
    if offsets[0] > start or last + resolution < end
        return false

    [ previous, others... ] = offsets
    for item in others
        if previous + resolution < item
            return false
        previous = item

    return true


class BucketCache
    constructor: () ->
        @clear()

    clear: () ->
        @resolutions = [] # sorted list of resolutions
        @cache = {}

    # low level API: getting/setting buckets
    getBucket: (resolution, offset) ->
        time = toTime(offset)
        return @cache[resolution]?.buckets[time]

    getBucketApproximate: (resolution, offset) ->
        time = toTime(offset)
        bucket = @getBucket(resolution, time)
        if bucket?
            return [bucket, true]

        resolutionIndex = bisect(@resolutions, resolution)
        while resolutionIndex >= 0
            nextResolution = @resolutions[resolutionIndex]
            resolutionIndex -= 1
            if not nextResolution?
                continue

            res = @cache[nextResolution]

            nextOffsetIndex = bisect(res.offsets, time) - 1
            nextOffset = res.offsets[nextOffsetIndex]

            # find offset covering the bucket we are interested in
            if nextOffset <= offset and (nextOffset + nextResolution) >= (time + resolution)
                value = res.buckets[nextOffset].count
                denom = (nextResolution / resolution)
                return [Math.round(value / denom), false]

        return [0, false]

    hasBucket: (resolution, offset) ->
        time = toTime(offset)
        return @cache[resolution]?.buckets[time]?

    setBucket: (resolution, offset, width, count) ->
        time = toTime(offset)
        @prepareResolution(resolution)
        @cache[resolution].buckets[time] = {
            offset: time,
            count: count,
            width: width,
        }
        insort(@cache[resolution].offsets, time)

    # bucket reservation API
    reserveBucket: (resolution, offset) ->
        time = toTime(offset)
        @prepareResolution(resolution)
        if not @hasBucket(resolution, time)
            @cache[resolution].buckets[time] = null

    isBucketReserved: (resolution, offset) ->
        time = toTime(offset)
        if @cache[resolution]?
            return @cache[resolution].buckets[time] is null

    hasBucketOrReserved: (resolution, offset) ->
        time = toTime(offset)
        return @hasBucket(resolution, time) or @isBucketReserved(resolution, time)

    isCountLower: (start, end, lowerThan) ->
        startTime = toTime(start)
        endTime = toTime(end)
        count = 0

        sumReducer = (acc, offset) ->
            return acc + res.buckets[offset].count

        # loop over all resolutions, starting with the lowest
        for resolution in @resolutions
            res = @cache[resolution]

            # get all offsets that intersect with start/end time
            offsetsWithin = res.offsets
                .filter((offset) ->
                    offset >= startTime and (offset + resolution) <= endTime
                )

            # calculate the sum of all records intersecting with start/end
            sum = offsetsWithin.reduce(sumReducer, 0)
            if sum > lowerThan
                return [ false, true ]

            # get all offsets that are strictly within start/end
            offsetsIntersecting = res.offsets
                .filter((offset) ->
                    (offset + resolution) > startTime and offset < endTime
                )

            # calculate the sum of all records that are strictly within start/end
            sum = offsetsIntersecting.reduce(sumReducer, 0)

            # if the sum is lower than the threshold, calculate whether the
            # offsets cover the whole of the given interval to be certain

            if sum < lowerThan and covers(startTime, endTime, offsetsIntersecting, resolution)
                return [ true, true ]

        return [ false, false ]

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
