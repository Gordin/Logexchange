# polyfill
unless String.prototype.startsWith
  Object.defineProperty(String.prototype, 'startsWith', {
    enumerable: false
    configurable: false
    writable: false
    value: (searchString, position) ->
      position = position or 0
      this.lastIndexOf(searchString, position) is position
  })


class Gadget
  constructor: (@callback) ->
    gadgets.openapp.connect @callback
    window.onunload = () ->
      gadgets.openapp.disconnect()

  publish: (envelope) ->
    envelope.publish()

class Envelope
  constructor: (@event, @type="namespaced-properties", @message, @uri, @date, @sharing, @sender, @viewer)->

  publish: () ->
    gadgets.openapp.publish(@)

class MultiGadget extends Gadget
  ###
  gadget can either be just the name of the gadget or an object.
  If it is an object, it needs at least a "name" attribute.
  The "regex", "connected", "incoming" and "callback" attributes are optional
  If callback is given, messages from this gadget will use this callback.
  ###
  constructor: (callback, @name, gadgets) ->
    @gadgets = {}
    for gadget in gadgets
      if typeof gadget is "string"
        @gadgets[gadget] =
          name: gadget
          regex: new RegExp(gadget+".xml$")
          connected: false
          incoming: []
      else if typeof gadget == "object"
        gadget.regex ?= new RegExp(gadget.name+".xml$")
        gadget.connected ?= false
        gadget.incoming ?= []
        @gadgets[gadget.name] = gadget

    @callback = (envelope, message) =>
      sender = envelope.sender
      if not @gadgets[sender]
        for name, gadget of @gadgets
          if gadget.regex.test(sender)
            @gadgets[sender] = gadget
            break
      gadget = @gadgets[sender]
      if gadget
        switch envelope.event
          when "enter"
            gadget.connected = true
            console.log("#{@name}: Gadget #{gadget.name} connected.")
          when "exit"
            gadget.connected = false
            console.log("#{@name}: Gadget #{gadget.name} disconnected.")
          else
            if gadget.callback
              gadget.callback envelope, message
            else
              callback envelope, message, gadget
      else
        callback envelope, message, false
    super @callback

  connect: () ->
    envelope = new Envelope "enter"
    envelope.publish()

  disconnect: () ->
    envelope = new Envelope "exit"
    envelope.publish()
