{ after, split, intersects, merged, subtract } = require '../utils.coffee'

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
        @reservedBuckets = []

    # add the interval with records to the cache. this can trigger a merge with
    # buckets.
    add: (start, end, records) ->
        @unReserve(start, end)
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

    # reserve an interval
    reserve: (start, end) ->
        [intersecting, nonIntersecting] = split(@reservedBuckets, ([startA, endA, ...]) ->
            intersects([start, end], [startA, endA])
        )

        if intersecting.length
            min = new Date(d3.min(intersecting, (b) -> b[0]))
            max = new Date(d3.max(intersecting, (b) -> b[1]))

            min = start if start < min
            max = end if start > max
            nonIntersecting.push([min, max])
        else
            nonIntersecting.push([start, end])

        @reservedBuckets = nonIntersecting

    unReserve: (start, end) ->
        [intersecting, nonIntersecting] = split(@reservedBuckets, ([startA, endA, ...]) ->
            intersects([start, end], [startA, endA])
        )

        int = [start, end]

        intervals = intersecting
            .map((interval) ->
                subtract(interval, int)
            )
            .reduce((acc, curr) ->
                return acc.concat(curr)
            , [])
        @reservedBuckets = nonIntersecting.concat(intervals)

    # fetch the source, but only the intervals that are required
    getMissing: (start, end, params, source, callback) ->
        intersecting = @getIntersecting(start, end, true)
        intervals = [[start, end],]
        for bucket in intersecting
            newIntervals = []
            for interval in intervals
                newIntervals = newIntervals.concat(subtract(interval, bucket))
            intervals = newIntervals

        return intervals

    getIntersecting: (start, end, includeReserved = false) ->
        records = @buckets.filter(([startA, endA, ...]) ->
            intersects([start, end], [startA, endA])
        )
        if includeReserved
            records = records.concat(@reservedBuckets.filter(([startA, endA, ...]) ->
                intersects([start, end], [startA, endA])
            ))
        return records

module.exports = RecordCache
