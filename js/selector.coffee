class SelectorGadget extends MultiGadget
  constructor: (callback) ->
      gadgets = ["StatGadget", "NetworkGadget"]
      super callback, "SelectorGadget", gadgets

  init: () ->
    env = new Envelope("enter")
    env.publish()

  # callback for OpenApp
  openAppCallback: (envelope, message) ->
    if(/StatGadget.xml$/.test(envelope.sender) or /SelectorGadget.xml$/.test(envelope.sender) or /explorerGadget.xml$/.test(envelope.sender))
      switch(envelope.event)
        when "error"
            console.log("Received error message from statistics gadget but the type is unknown: " + envelope.message["http://purl.org/dc/terms/type"])
        when "enter"
          console.log("OpenApp: entered", envelope, message)
        when "exit"
          console.log("OpenApp: exited")
        else
          # switch(envelope.message["http://purl.org/dc/terms/type"]
          console.log("Received unknown event message from gadget: " + envelope.sender + " Message: " + envelope.event)
    else
      console.log("Received (MasterGadget) unknown event message from unknown sender: " + envelope.sender + " Event: " + envelope.event + " Message: " + envelope.message)
      # console.log("Received (MasterGadget) unknown event message from unknown sender: " + envelope.sender + " Event: " + envelope.event + " Message: " + envelope.message["http://purl.org/dc/terms/type"])
      # console.log envelope

window.gadget_init = () ->
  gadget = new SelectorGadget(
    (envelope, message, gadget) ->
      # console.log envelope
      # console.log message
      # console.log gadget
  )
  console.log "SelectorGadget: ", gadget
  init_ui()
  gadget.connect()
  # xmpp_connect()

conn = null
verified_servers = {}
pending = {}
active_cmd = null
active_sessions = {}

add_server = (server) ->
  verified_servers[server] = true
  $("div#ServerDiv select#serverChoose")
  .append($ '<option/>',
    value: server
    text: server)
  .val(server)
  $("#StatusButton").prop("disabled", false)
  $("#StanzaButton").prop("disabled", false)
  get_sessions(server)

log_handler = (log) ->
  if (not active_sessions[log.id]) and (not pending[log.id])
    pending[log.id] = true
    console.log log.id, active_sessions[log.id]
    get_sessions(Strophe.getDomainFromJid log.subject)
    get_sessions(Strophe.getDomainFromJid log.object)
  env = new Envelope "logexchange_#{log.module}", undefined, log
  env.publish()
  console.log "Published: ", env
  true

session_added = (type, id, server) ->
  unless active_sessions[id]
    $("#SessionsDiv fieldset").append(
      """
      <div id="session_#{id}">
        <label style="width: 70%;" for="stop_#{id}">#{server} - #{type} - #{id}</label>
        <!-- <button type="button" id="vis_#{id}" onclick="visualize('#{id}');">Visualize</button>
        <button type="button" id="reconf_#{id}" onclick="reconf_session('#{id}');">Reconfigure</button>-->
        <button type="button" id="stop_#{id}" onclick="stop_session('#{server}', '#{id}');">Stop</button>
      </div>
      """)
    active_sessions[id] = type
    pending[id] = false
  else
    $("#SessionsDiv fieldset #session_#{id}").html(
      """
        <label style="width: 70%;" for="stop_#{id}">#{server} - #{type} - #{id}</label>
        <!-- <button type="button" id="vis_#{id}" onclick="visualize('#{id}');">Visualize</button>
        <button type="button" id="reconf_#{id}" onclick="reconf_session('#{id}');">Reconfigure</button>-->
        <button type="button" id="stop_#{id}" onclick="stop_session('#{server}', '#{id}');">Stop</button>
      """
    )


stop_session = (server, id) ->
  conn.logexchange.stop_session server, id, () ->
    $("#session_#{id}").remove()

get_sessions = (server) ->
  server = conn.domain unless server
  cb = (sessions, types) ->
    return unless types
    typemapping = {
      "stanza": "stanzalog"
      "status": "statuslog"}
    `var i`
    for session in sessions
      session_added typemapping[types[_i]], session, server
    return
  conn.logexchange.get_sessions server, cb


# Calls callback if the server speaks the logexchange protocal and calls err etherwise
test_logexchange = (server, callback, err) ->
  conn.disco.info server, (stanza) ->
    if $(stanza).find("feature[var='urn:xmpp:logexchange']").length
      # Server advertises logexchange capabilities
      conn.disco.items server, 'http://jabber.org/protocol/commands', (stanza) ->
        if $(stanza).find("item[node='logexchange/stanza']").length
          callback()
        else err()
    else err()

test_logexchange_ui = () ->
  server = $("#addServer").val()
  if verified_servers[server]
    return
  #   alert("Server is already added.")
  test_logexchange(
    server,
    ()->
      $("button#addButton")
      add_server server
    ,()->
      $("button#addButton")
      .prop("disabled", true)
      alert("Server does offer the logexchange protocol to your JID.")
  )

init_stanzalog = ->
  server = $("#addServer").val()
  conn.logexchange.request_stanzalogs(server, success, error) ->
    XXX

xmpp_connect = ->
  jid = Strophe.getBareJidFromJid($('#loginJID').val()) + "/SelectorGadget"
  password = $('#loginPassword').val()
  proxyurl = "ws://#{Strophe.getDomainFromJid(jid)}:5280/xmpp-websocket"
  conn = new Strophe.Connection proxyurl
  # conn.xmlInput  = (body) -> console.log "In:", body.outerHTML or body.tree and body.tree() or body
  # conn.xmlOutput = (body) -> console.log "Out:", body.outerHTML or body.tree and body.tree() or body
  conn.connect(jid,  password,
    (status) ->
      stats =
        {0: "ERROR", 1: "CONNECTING", 2: "CONNFAIL", 3: "AUTHENTICATING",
        4: "AUTHFAIL", 5: "CONNECTED", 6: "DISCONNECTED",
        7: "DISCONNECTING", 8: "ATTACHED"}
      console.log("XMPP Status change: " + stats[status])
      if status is Strophe.Status.CONNECTED
        $(document).trigger 'xmpp-connected'
      else if status is Strophe.Status.DISCONNECTED
        $(document).trigger 'xmpp-disconnected'
  )
  window.conn = conn

xmpp_disconnect = ->
  window.conn.disconnect()
  $("div#ServerDiv").hide()
  $("div#SessionsDiv").hide()
  $("div#loginDiv").show()

$(document).bind(
  'xmpp-connected': (ev, data) ->
    unload = window.unload
    window.onunload = ->
      conn.disconnect()
      unload()
    conn.eventlog.addHandler log_handler
    sdiv = $("div#ServerDiv")
    legend = sdiv.find("#ServerForm legend")
    legend.text("Server Selector - connected as #{Strophe.getBareJidFromJid(conn.jid)}")
    $("#addServer").val(conn.domain)
    test_logexchange_ui()
    $("div#loginDiv").hide()
    sdiv.show()
    $("div#SessionsDiv").show()

  'xmpp-disconnected': (ev, data) ->
    # $("div#ServerDiv").hide()
    # $("div#loginDiv").show()
)

init_ui = ->
  $("input#addServer").keyup (ev) ->
    if ev.target.value.length > 0
      $("#addButton").prop("disabled", false)
    else
      $("#addButton").prop("disabled", true)

  $("button#addButton")
    .click(test_logexchange_ui)

  $("select#serverChoose").change (ev) ->
    $("#StatusButton").prop("disabled", false)
    $("#StanzaButton").prop("disabled", false)

  $("#StatusButton").click ->
    server = $("select#serverChoose").val()

  $("#StanzaButton").click ->
    server = $("select#serverChoose").val()
    active_cmd = conn.logexchange.new_stanzalog server,
      (stanza, cmd) ->
        fill_stanzaform cmd
        $("div#ServerDiv").hide()
        $("div#StanzaFormDiv").show()
      ,() ->
        console.log arguments

  $("#StatusButton").click ->
    server = $("select#serverChoose").val()
    active_cmd = conn.logexchange.new_statuslog server,
      (stanza, cmd) ->
        fill_statusform cmd
        $("div#ServerDiv").hide()
        $("div#StatusFormDiv").show()
      ,() ->
        console.log arguments

  $("#cancelStanza").click ->
    $("div#StanzaFormDiv").hide()
    $("div#ServerDiv").show()

  $("#cancelStatus").click ->
    $("div#StatusFormDiv").hide()
    $("div#ServerDiv").show()

  $("#sendStanza").click ->
    response_form = read_stanzaform active_cmd
    logid = null
    for f in response_form.fields
      if f.var is "logid"
        logid = f.values[0]
        break
    active_cmd.complete(
      responseForm: response_form
      success: (stanza, cmd) ->
        console.log @, active_cmd
        session_added "stanzalog", logid, cmd.jid
    )
    $("div#StanzaFormDiv").hide()
    $("div#ServerDiv").show()

  $("#sendStatus").click ->
    response_form = read_statusform active_cmd
    logid = null
    for f in response_form.fields
      if f.var is "logid"
        logid = f.values[0]
        break
    active_cmd.complete(
      responseForm: response_form
      success: (stanza, cmd) ->
        session_added "statuslog", logid, cmd.jid
    )
    $("div#StatusFormDiv").hide()
    $("div#ServerDiv").show()

  $("#statistictsAll").click ->
    $("#status_stats option").prop "selected", true

  $("#statistictsNone").click ->
    $("#status_stats option").prop "selected", false

fill_statusform = (cmd) ->
  form = cmd.form
  fields = form.fields
  sform = $ "form#StatusForm"
  for field in fields
    switch field.var
      when "statustype"
        item = sform.find "#status_stats"
        item.html ""
        # item.attr("size", field.values.length)
        for option in field.options
          item.append($ '<option/>',
            value: option.value
            text: option.label)
        for value in field.values
          item.find("option[value='#{value}']")
          .prop "selected", true
      when "onupdate"
        item = sform.find "#status_onupdate"
        # if field.values[0] is "1"
        #   item.prop "checked", true
        # else
        #   item.prop "checked", false
        item.prop "checked", false
      when "interval"
        sform.find("#status_interval")
        .val field.values[0]

read_statusform = (cmd) ->
  form = cmd.form
  fields = form.fields
  sform = $ "form#StatusForm"
  new_fields = []
  for field in fields
    v = field.var
    t = field.type
    values = []
    switch v
      when "logid"
        values = field.values
      when "statustype"
        item = sform.find "#status_stats"
        for option in field.options
          if item.find("option[value='#{option.value}']").prop "selected"
            values.push option.value
      when "onupdate"
        item = sform.find "#status_onupdate"
        if item.prop "checked"
          values = ["1"]
        else
          values = ["0"]
      when "interval"
        values = [sform.find("#status_interval").val() or ""]
    new_fields.push new Strophe.x.Field(var: v, type: t, values: values)
  response_form = new Strophe.x.Form(
    type: "submit",
    fields: new_fields)
  return response_form

fill_stanzaform = (cmd) ->
  form = cmd.form
  fields = form.fields
  sform = $ "form#StanzaForm"
  for field in fields
    switch field.var
      when "stanzatype"
        stanzatypes = sform.find "select#stanzatypes"
        stanzatypes.find("option").each (index) ->
          $(@).prop "selected", false
        for value in field.values
          stanzatypes.find("#stanzatype_#{value}").prop("selected", true)
      when "jid"
        jids = sform.find "#stanza_jids"
        jids.text ""
        for value in field.values
          jids.append "#{value}\n"
        jids.text jids.text().trim()
      when "conditions", "direction"
        item = sform.find "#stanza_#{field.var}"
        item.html ""
        # item.attr("size", field.values.length)
        for option in field.options
          item.append($ '<option/>',
            value: option.value
            text: option.label)
        for value in field.values
          item.find("option[value='#{value}']")
          .prop "selected", true
      when "input"
        input = sform.find "#stanza_queries"
        input.text ""
        for value in field.values
          input.append "#{value}\n"
        input.text jids.text().trim()
      when "top", "private", "iqresponse"
        item = sform.find "#stanza_#{field.var}"
        if field.values[0] is "1"
          item.prop "checked", true
        else
          item.prop "checked", false
      when "output"
        sform.find("#stanza_output")
        .val field.values[0]

read_stanzaform = (cmd) ->
  form = cmd.form
  fields = form.fields
  sform = $ "form#StanzaForm"
  new_fields = []
  for field in fields
    v = field.var
    t = field.type
    values = []
    switch v
      when "logid"
        values = field.values
      when "stanzatype"
        stanzatypes = sform.find "select#stanzatypes"
        for option in field.options
          if stanzatypes.find("#stanzatype_#{option.value}").prop("selected")
            values.push option.value
      when "jid"
        jids = sform.find "#stanza_jids"
        txt = jids.text()
        if txt.trim() != ""
          values = txt.split('\n')
      when "conditions", "direction"
        item = sform.find "#stanza_#{field.var}"
        for option in field.options
          if item.find("option[value='#{option.value}']").prop "selected"
            values.push option.value
      when "input"
        input = sform.find "#stanza_queries"
        txt = input.text()
        if txt.trim() != ""
          values = txt.split('\n')
      when "top", "private", "iqresponse"
        item = sform.find "#stanza_#{field.var}"
        if item.prop "checked"
          values = ["1"]
        else
          values = ["0"]
      when "output"
        values = [sform.find("#stanza_output").val()]
    new_fields.push new Strophe.x.Field(var: v, type: t, values: values)
  response_form = new Strophe.x.Form(
    type: "submit",
    fields: new_fields)
  return response_form

