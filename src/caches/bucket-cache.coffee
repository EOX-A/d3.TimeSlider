
class BucketCache:
    constructor: () ->
        @cache = {}

    get: (resolution, offset) ->

    set: (resolution, offset, count) ->
        @cache[resolution] = {} if not @cache[resolution]
        @cache[resolution][offset] = count

module.exports = BucketCache
