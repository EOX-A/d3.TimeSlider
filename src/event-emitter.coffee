class EventEmitter
    constructor: (@dispatchElement) ->
        @listeners = d3.dispatch() # TODO

    on: (args...) ->
        @listeners.on(args...)

    dispatch: (name, detail, dispatchElement) ->
        evt = document.createEvent('CustomEvent')
        evt.initCustomEvent(name, true, true, detail)
        (dispatchElement or @dispatchElement).dispatchEvent(evt)
