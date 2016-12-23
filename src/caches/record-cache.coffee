{ after, intersects, merged, subtract } = require '../utils.coffee'

# cache for records and their respective intervals
class RecordCache
    constructor: (@idProperty) ->
        if @idProperty
            @predicate = (a, b) -> a[2][@idProperty] is b[2][@idProperty]
        else
            @predicate = (a, b) -> a[0] is b[0] and a[1] is b[1]
        @clear()

    # clear the cache
    clear: () ->
        @buckets = []

    # add the interval with records to the cache. this can trigger a merge with
    # buckets.
    add: (start, end, records) ->
        intersecting = @getIntersecting(start, end)
        notIntersecting = @buckets
            .filter(([startA, endA, ...]) -> not intersects([start, end], [startA, endA]))

        low = start
        high = end
        combined = records

        for [bucketStart, bucketEnd, bucketRecords] in intersecting
            low = bucketStart if bucketStart < low
            high = bucketEnd if bucketEnd > high
            combined = merged(combined, bucketRecords, @predicate)
        @buckets = notIntersecting
        @buckets.push([low, high, combined])

    # get the records for the given interval (can be of more than one bucket)
    get: (start, end) ->
        intersecting = @getIntersecting(start, end)
        if intersecting.length == 0
            return []

        [first, others...] = intersecting
        records = first[2]
        for intersection in others
            records = merged(records, intersection[2], @predicate)
        return records

    # fetch the source, but only the intervals that are required
    fetch: (start, end, params, source, callback) ->
        intersecting = @getIntersecting(start, end)
        intervals = [[start, end],]
        for bucket in intersecting
            newIntervals = []
            for interval in intervals
                newIntervals = newIntervals.concat(subtract(interval, bucket))
            intervals = newIntervals

        if intervals.length
            summaryCallback = after(intervals.length, () =>
                callback(@get(start, end))
            )

            for [intStart, intEnd] in intervals
                source(intStart, intEnd, params, (records, paths) =>
                    @add(intStart, intEnd, records)
                    summaryCallback()
                )
        else
            # fill entire answer from cache
            callback(@get(start, end))

    getIntersecting: (start, end) ->
        return @buckets
            .filter(([startA, endA, ...]) ->
                intersects([start, end], [startA, endA])
            )

module.exports = RecordCache
