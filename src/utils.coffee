split = (list, predicate) ->
    a = []
    b = []
    for item in list
        if predicate(item)
            a.push(item)
        else
            b.push(item)
    return [a, b]

intersects = (a, b) ->
    return a[0] <= b[1] and b[0] <= a[1]

distance = (a, b, scale) ->
    if intersects(a, b)
        return 0
    else
        return Math.min(
            Math.abs(scale(a[0]) - scale(b[0])),
            Math.abs(scale(a[1]) - scale(b[1]))
        )

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

module.exports =
    split: split,
    intersects: intersects,
    distance: distance,
    merged: merged,
    after: after,
    subtract: subtract
