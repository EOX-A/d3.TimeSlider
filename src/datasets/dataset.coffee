EventEmitter = require '../event-emitter.coffee'

# Dataset utility class for internal use only
class Dataset extends EventEmitter
    constructor: ({ @id,  @color, @source, @sourceParams, @index, @records,
                    @paths, @lineplot, @ordinal, @element, @histogramThreshold,
                    @histogramBinCount, @cluster, cacheRecords, cacheIdField,
                    debounceTime}) ->
        @fetchDebounced = debounce(@doFetch, debounceTime)
        @currentSyncState = 0
        super(@element)

    getSource: ->
        @source

    setSource: (@source) ->

    setRecords: (@records) ->

    getRecords: -> @records

    setPaths: (@paths) ->

    getPaths: -> @paths

    sync: (args...) ->
        @fetchDebounced(args...)

    doFetch: (start, end, callback) ->
        @currentSyncState += 1
        syncState = @currentSyncState
        fetched = (records) =>
            # only update the timeslider when the state is still valid
            if syncState == @currentSyncState
                callback(@postprocess(records))

        # sources conforming to the Source interface
        if @source and typeof @source.fetch == 'function'
            source = (args...) =>
                @source.fetch(args...)
        # sources that are functions
        else if typeof @source == 'function'
            source = @source
        # no source, simply call the callback with the static records and paths
        else
            return callback(@records || @paths)

        if @cache
            @cache.fetch(start, end, @sourceParams, source, fetched)
        else
            source(start, end, @sourceParams, fetched)

    # process synced records
    postprocess: (records) ->
        return records

    draw: () ->

module.exports = Dataset
