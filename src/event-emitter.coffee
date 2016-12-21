class EventEmitter
    constructor: (@dispatchElement, events...) ->
        if events.length
            @listeners = d3.dispatch.apply(undefined, events)

    on: (args...) ->
        @listeners.on(args...)

    dispatch: (name, detail, dispatchElement) ->
        evt = document.createEvent('CustomEvent')
        evt.initCustomEvent(name, true, true, detail)
        (dispatchElement or @dispatchElement).dispatchEvent(evt)

module.exports = EventEmitter
