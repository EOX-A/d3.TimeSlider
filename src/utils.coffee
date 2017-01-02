split = (list, predicate) ->
    a = []
    b = []
    for item in list
        if predicate(item)
            a.push(item)
        else
            b.push(item)
    return [a, b]

bisect = (array, x, lo = 0, hi = array.length) ->
  while lo < hi
      mid = Math.floor((lo + hi) / 2)
      if x < array[mid]
          hi = mid
      else
          lo = mid + 1
  return lo

insort = (array, x) ->
    array.splice(bisect(array, x), 0, x);

intersects = (a, b) ->
    return a[0] <= b[1] and b[0] <= a[1]

pixelDistance = (a, b, scale) ->
    if intersects(a, b)
        return 0
    else
        return Math.min(
            Math.abs(scale(a[0]) - scale(b[0])),
            Math.abs(scale(a[1]) - scale(b[1]))
        )

pixelWidth = (interval, scale) ->
    return scale(interval[1]) - scale(interval[0])

pixelMaxDifference = (a, b, scale) ->
    diffs = subtract(a, b)
    if diffs.length is 0
        return 0
    else
        return Math.max(diffs.map(
            (diff) -> pixelWidth(diff, scale)
        )...)

# merge two arrays of objects according to an equality predicate
merged = (a, b, predicate) ->
    out = a[..]
    for r2 in b
        if not a.find((r1) -> predicate(r1, r2))
            out.push(r2)
    return out

# invoke final callback after n calls
after = (n, callback) ->
    count = 0
    return (args...) ->
        ++count
        if count == n
            callback(args...)

# subtract one interval from another. returns a list of intervals
subtract = (a, b) ->
    if not intersects(a, b)
        # a: |----|
        # b:        |----|
        # o: |----|
        return [a]
    else if a[0] < b[0] and a[1] > b[1]
        # a: |--------|
        # b:    |--|
        # =: |--|  |--|
        return [
            [ a[0], b[0], ],
            [ b[1], a[1], ],
        ]
    else if a[0] < b[0]
        # a: |--------|
        # b:    |-------|
        # =: |--|
        return [[a[0], b[0],],]
    else if a[1] > b[1]
        # a:    |------|
        # b: |------|
        # =:        |--|
        return [[b[1], a[1],],]
    else
        # a:   |--|
        # b: |------|
        # o:
        return []

parseDuration = (duration) ->
    if not isNaN(parseFloat(duration))
        return parseFloat(duration)

    matches = duration.match(/^P(?:([0-9]+)Y|)?(?:([0-9]+)M|)?(?:([0-9]+)D|)?T?(?:([0-9]+)H|)?(?:([0-9]+)M|)?(?:([0-9]+)S|)?$/)

    if matches
        years = (parseInt(matches[1]) || 0) # years
        months = (parseInt(matches[2]) || 0) + years * 12 # months
        days = (parseInt(matches[3]) || 0) + months * 30 # days
        hours = (parseInt(matches[4]) || 0) + days * 24 # hours
        minutes = (parseInt(matches[5]) || 0) + hours * 60 # minutes
        return (parseInt(matches[6]) || 0) + minutes * 60 # seconds

offsetDate = (date, seconds) ->
    return new Date(date.getTime() + seconds * 1000)

centerTooltipOn = (tooltip, target, dir = 'center', offset = [0, 0]) ->
    rect = target.getBoundingClientRect()
    tooltipRect = tooltip[0][0].getBoundingClientRect()
    if dir == 'left'
        xOff = rect.left
    else if dir == 'right'
        xOff = rect.right
    else
        xOff = rect.left + rect.width / 2
    tooltip
        .style('left', xOff - tooltipRect.width / 2 + offset[0] + "px")
        .style('top', (rect.top - tooltipRect.height) + offset[1] + "px")

module.exports =
    split: split
    bisect: bisect
    insort: insort
    intersects: intersects
    pixelDistance: pixelDistance
    pixelWidth: pixelWidth
    pixelMaxDifference: pixelMaxDifference
    merged: merged
    after: after
    subtract: subtract
    parseDuration: parseDuration
    offsetDate: offsetDate
    centerTooltipOn: centerTooltipOn
