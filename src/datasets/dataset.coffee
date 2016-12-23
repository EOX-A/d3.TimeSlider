debounce = require 'debounce'
EventEmitter = require '../event-emitter.coffee'

# Dataset utility class for internal use only
class Dataset extends EventEmitter
    constructor: ({ @id,  @color, @source, @sourceParams, @index, @records,
                    @paths, @lineplot, @ordinal, @element, debounceTime}) ->
        @fetchDebounced = debounce(@doFetch, debounceTime)
        @currentSyncState = 0
        @lastSyncState = 0
        super(@element[0][0], 'syncing', 'synced')

    getSource: ->
        @source

    setSource: (@source) ->

    setRecords: (@records) ->

    getRecords: -> @records

    setPaths: (@paths) ->

    getPaths: -> @paths

    sync: (args...) ->
        @fetchDebounced(args...)

    isSyncing: () ->
        return !(@lastSyncState is @currentSyncState)

    getSourceFunction: (source) ->
        # sources conforming to the Source interface
        if source and typeof source.fetch == 'function'
            return (args...) =>
                source.fetch(args...)
        # sources that are functions
        else if typeof source == 'function'
            return source

    doFetch: (start, end, params) ->
        @currentSyncState += 1
        syncState = @currentSyncState
        @listeners.syncing()

        fetched = (records) =>
            # only update the timeslider when the state is still valid
            @lastSyncState = syncState if syncState > @lastSyncState
            if syncState == @currentSyncState
                if not @cache
                    @records = @postprocess(records)
                @listeners.synced()

        if @source
            source = @getSourceFunction(@source)
        # no source, simply call the callback with the static records and paths
        else
            @lastSyncState = syncState if syncState > @lastSyncState
            @listeners.synced()
            return

        if @cache
            @cache.fetch(start, end, @sourceParams, source, fetched)
        else
            source(start, end, @sourceParams, fetched)

    # process synced records
    postprocess: (records) ->
        return records

    draw: () ->

module.exports = Dataset
