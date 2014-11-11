class NetworkGadget extends MultiGadget
  constructor: (callback) ->
      gadgets = ["SelectorGadget", "StatGadget"]
      super callback, "NetworkGadget", gadgets

  init: () ->
    env = new Envelope("enter")
    env.publish()

  # callback for OpenApp
  openAppCallback: (envelope, message) ->
    if(/StatGadget.xml$/.test(envelope.sender) or /SelectorGadget.xml$/.test(envelope.sender) or /NetworkGadget.xml$/.test(envelope.sender))
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
      console.log envelope

window.gadget_init = () ->
  gadget = new NetworkGadget(
    (envelope, message, gadget) ->
      envelope_handler envelope
      # console.log envelope
      # console.log message
      # console.log gadget
  )
  console.log "NetworkGadget: ", gadget
  init_ui()
  gadget.connect()
  # draw_jsnx()

envelope_handler = (env) ->
  if env.event.startsWith "logexchange_Stanza"
    log_handler env.message

log_handler = (log) ->
  return unless graph
  graph.add_log log

min_r = 5
max_r = 40
calc_r = max_r - min_r

min_width = 1
max_width = 10
calc_width = max_width - min_width

getDomainFromJid = (jid) ->
  bare = getBareJidFromJid(jid)
  if bare.indexOf("@") < 0
    return bare
  else
    parts = bare.split("@")
    parts.splice(0, 1)
    return parts.join('@')

getBareJidFromJid = (jid) ->
  if jid then jid.split("/")[0] else null

link_nodes = (x, y, mode, p2p) ->
  return if x.id is y.id
  x_id = x.id
  y_id = y.id
  lo = mode.links_obj
  lo[x_id] ?= {}
  lo[y_id] ?= {}
  link = lo[x_id][y_id]
  new_link = false
  unless link
    if x_id < y_id
      link = new Link x, y, p2p
    else
      link = new Link y, x, p2p
    new_link = true
    lo[x_id][y_id] = link
    lo[y_id][x_id] = link
    mode.links.push link

    max_value = +line_slider.attr "max"
    if mode.links.length >= max_value
      max = (max_value <= +line_slider.attr "value")
      line_slider.attr "max", mode.links.length + 1
      if max
        line_slider.attr "value", mode.links.length + 1

  link.count++
  link.p2p = true if p2p

  mode.max_line_count = d3.max([mode.max_line_count, link.count])
  # max = line_slider.attr("value") == mode.max_line_count + 1
  # line_slider.attr "max", mode.max_line_count + 1
  # if max
  #   line_slider.attr "value", mode.max_line_count + 1

  new_link

class Node
  constructor: (@id, @weight=8, @start) ->
    @type = "@" in @id and "client" or "server"
    @links = {}
    @count = 0

  getText: (hide) ->
    return @id unless hide
    if @type is "client"
      jidsplit = @id.split("@")
      node = ""
      for _ in jidsplit[0]
        node += "…"
      return "#{node}@#{jidsplit[1]}"
    else
      return @id


class Link
  @color: "#000000"
  @p2pcolor: "#F00000"

  @opacity: "0.3"
  @p2popacity: "1.0"

  constructor: (@source, @target, @p2p, @start) ->
    @count = 0
    @width = 1.5
    @start = @source.start

  getColor: ->
    if @p2p then Link.p2pcolor else Link.color

  getOpacity: ->
    if @p2p then Link.p2popacity else Link.opacity

class Graph
  physical: {
    max_line_count: 1
    links_obj: {}
    links: []
    nodes: []
    nodes_obj: {}
    name: "physical"
  }

  logical: {
    max_line_count: 1
    links_obj: {}
    links: []
    nodes: []
    nodes_obj: {}
    name: "logical"
  }

  constructor: () ->
    @width = 500
    @height = 400
    @height_brush = 50

    @color = d3.scale.category20()
    @timescale = null

    @force = null
    @drag = null
    @svg = null
    @brush = null
    @xAxis = null
    @circles = null
    @lines = null
    @logs = []
    @mode = @physical

  tick: (that) ->
    ->
      # that.circles.select("circle")
        # .attr("cx", (d) -> d.x )
        # .attr("cy", (d) -> d.y )
        # .attr("r", (d) -> that.get_node_width(d))

      that.circles
        .attr("transform", (d) -> "translate(#{d.x},#{d.y})scale(#{that.inv_scale})")
      that.lines
        .attr("x1", (d) -> d.source.x )
        .attr("y1", (d) -> d.source.y )
        .attr("x2", (d) -> d.target.x )
        .attr("y2", (d) -> d.target.y )
        .style("stroke-width", (d) -> that.inv_scale * that.get_line_width(d))
        # .attr("transform", (d) -> "scale(#{that.inv_scale})")

  resize: (that) ->
    ->
      topOffset = d3.select("#NetworkControlDiv").node().offsetHeight
      d3.select("#network").style "top", "#{topOffset}px"
      that.width = window.innerWidth
      that.height = window.innerHeight - topOffset
      that.svg
        .attr("width", that.width)
        .attr("height", that.height)
      that.overlay
        .attr("width", that.width * 4)
        .attr("height", (that.height - that.height_brush) * 4)
      that.force.size([that.width, that.height - that.height_brush]).resume()
      that.timescale.range([0, that.width])
      that.brush.x(that.timescale)
      that.context
        .attr("transform", "translate(0,#{that.height - that.height_brush})")
        .call(that.xAxis)

  dblclick: (that) ->
    (d) ->
      d3.select(@).classed("fixed", d.fixed = false)
      that.force.start()

  dragstart: (d) ->
    d3.event.sourceEvent.stopPropagation()
    d3.select(@).classed("fixed", d.fixed = true)

  zoomfunc: (that) ->
    ->
      if that.current_zoom is "geometric"
        that.network.attr("transform", "translate(#{d3.event.translate})scale(#{d3.event.scale})")
      else if that.current_zoom is "semantic"
        that.circles.attr("transform", that.semantic_zoom_transform)
  current_zoom: "geometric"

  # semantic_zoom_transform: (d) ->
  #   "translate(#{x(d[0])},#{y(d[1])})"

  export_gexf: ->
    gexf = document.createElement "gexf"
    gexf.setAttribute("xmlns", "http://www.gexf.net/1.2draft")
    gexf.setAttribute("xmlns:viz", "http://www.gexf.net/1.2draft/viz")
    gexf.setAttribute("version", "1.2")

    gg = document.createElement "graph"
    gg.setAttribute "mode", "dynamic"
    gg.setAttribute "timeformat", "dateTime"
    gg.setAttribute "defaultedgetype", "undirected"
    gexf.appendChild gg

    tempStore = {}
    gnodes = document.createElement "nodes"
    for n, i in @force.nodes()
      gnode = document.createElement "node"
      gnode.setAttribute "id", i
      gnode.setAttribute "start", n.start
      gnode.setAttribute "label", n.id
      tempStore[n.id] = i

      color = hexToRgb @color getDomainFromJid n.id
      gcolor = document.createElement "viz:color"
      gcolor.setAttribute "r", color.r
      gcolor.setAttribute "g", color.g
      gcolor.setAttribute "b", color.b
      gnode.appendChild gcolor

      gposition = document.createElement "viz:position"
      gposition.setAttribute "x", n.x
      gposition.setAttribute "y", @height - n.y
      gposition.setAttribute "z", 0
      gnode.appendChild gposition

      gshape = document.createElement "viz:shape"
      gshape.setAttribute "value", "disc"

      gsize = document.createElement "viz:size"
      gsize.setAttribute "value", @get_node_width n
      gnode.appendChild gsize

      gnodes.appendChild gnode
    gg.appendChild gnodes

    gedges = document.createElement "edges"
    for l, i in @force.links()
      glink = document.createElement "edge"
      glink.setAttribute "id", i
      glink.setAttribute "source", tempStore[l.source.id]
      glink.setAttribute "target", tempStore[l.target.id]
      glink.setAttribute "start", l.start
      glink.setAttribute "weight", l.count

      color = hexToRgb l.getColor()
      gcolor = document.createElement "viz:color"
      gcolor.setAttribute "r", color.r
      gcolor.setAttribute "g", color.g
      gcolor.setAttribute "b", color.b
      gcolor.setAttribute "a", l.getOpacity()
      glink.appendChild gcolor

      thick = document.createElement "viz:thickness"
      thick.setAttribute "value", l.width
      glink.appendChild thick

      gedges.appendChild glink
    gg.appendChild gedges

    data = "application/xml;charset=utf-8," + encodeURIComponent(gexf.outerHTML)
    d3.select("#export_link")
      .attr("href", "data:#{data}")
      .attr("download", "export.gexf")
    export_click()
    return gexf

  export_logs: ->
    data = "text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(@logs))
    d3.select("#export_link")
      .attr("href", "data:#{data}")
      .attr("download", "logs.json")
    export_click()

  import_logs: (json) ->
    logs = JSON.parse(json)
    for log in logs
      @add_log log
    return

  start: ->
    @force = d3.layout.force()
      .nodes(@mode.nodes)
      .links(@mode.links)
      .charge(-300)
      # .gravity(0.1)
      # .friction(0.6)
      .theta(0.5)
      .linkDistance(120)
      .size([@width, @height - @height_brush])
      .on("tick", @tick(@))

    @drag = @force.drag()
      .on("dragstart", @dragstart)

    first_date = @logs[0]?.timestamp and new Date(@logs[0].timestamp) or new Date()
    @timescale = d3.time.scale().range([0, @width]).domain([first_date, first_date])
    @xAxis = d3.svg.axis().scale(@timescale).orient("bottom")

    @brush = d3.svg.brush()
      .x(@timescale)
      .on("brush", @brushed)

    @svg = d3.select("#network").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("xmlns", "http://www.w3.org/2000/svg")
      .style("font-family", "arial,sans-serif")

    @zoom_scale = 1
    @inv_scale = 1

    @zoom = d3.behavior.zoom()

    @network = @svg
      .append("g")
        .call(@zoom.on("zoom", =>
          if d3.event.sourceEvent instanceof WheelEvent
            if d3.event.sourceEvent.shiftKey
              @inv_scale = @inv_scale * @zoom_scale / d3.event.scale
            @zoom_scale = d3.event.scale
            if d3.event.sourceEvent.shiftKey
              @network.attr("transform", "translate(#{d3.event.translate})scale(#{d3.event.scale})")
              @circles.attr("transform", (d) => "translate(#{d.x},#{d.y})scale(#{@inv_scale})")
            else
              @network.transition().duration(200)
                  .attr("transform", "translate(#{d3.event.translate})scale(#{d3.event.scale})")
                .selectAll(".node")
                  .attr("transform", (d) => "translate(#{d.x},#{d.y})scale(#{@inv_scale})")
            # @circles.attr("transform", (d) => "translate(#{d.x},#{d.y})scale(#{@inv_scale})")
          else
            @network.attr("transform", "translate(#{d3.event.translate})scale(#{d3.event.scale})")
            @circles.attr("transform", (d) => "translate(#{d.x},#{d.y})scale(#{@inv_scale})")
          @force.start()
        ))
        .on("dblclick.zoom", null)
      .append("g")
        .attr("id", "network")

    @overlay = @network.append("rect")
      .attr("class", "overlay")
      .attr("width", @width * 4)
      .attr("height", (@height - @height_brush) * 4)
      .attr("transform", "translate(-#{@width / 4},-#{(@height - @height_brush) * 2})")
      .style("fill", "none")
      .style("pointer-events", "all")

    @context = @svg.append("g")
      .attr("class", "context")
      .attr("title", "Selecting an area here will restrict the graph to nodes and links in the selected time period.")
      .attr("transform", "translate(0,#{@height - @height_brush})")

    @context.append("g")
      .attr("class", "x axis")
      # .attr("transform", "translate(0,#{@height - @height_brush - 50})")
      .call(@xAxis)

    @brushsvg = @context.append("g")
      .attr("class", "x brush")
      .call(@brush)

    @brushsvg.selectAll("rect")
      .attr("y", -6)
      .attr("height", @height_brush + 7)

    (@resize(@))()
    d3.select(window).on("resize", @resize(@))
    @brush.extent(@timescale.domain())
    @brushsvg.call(@brush)

    @svg.selectAll(".brush")
        .style("stroke", "#fff")
        .style("fill-opacity", ".5")
        .style("shape-rendering", "crispEdges")
      .selectAll(".extent")
        .style("stroke", "#fff")
        .style("fill-opacity", ".125")
        .style("shape-rendering", "crispEdges")

    @svg.select(".axis line")
      .style("stroke", "#000")
      .style("fill", "none")
      .style("shape-rendering", "crispEdges")

    @limit Infinity, Infinity

  queue_redraw: ->
    return if @queued
    @queued = true
    d3.timer =>
        @create_svg_elements()
        @queued = false
        return true
      , 500

  create_svg_elements: ->
    @force.stop()

    @lines = @network.selectAll(".link")
    @lines = @lines
      .data(@force.links(), (d) -> d.source.id + "-#{d.target.id}" )
      .attr("stroke-width", (d) => @get_line_width(d))

    @lines.enter().insert("line", ".node")
      .attr("class", "link")
      .attr("stroke-width", (d) => @get_line_width(d))
      .style("stroke", (d) -> d.getColor())
      .style("stroke-width", "1.5px")
      .style("stroke-opacity", (d) -> d.getOpacity())
    @lines.exit().remove()


    @circles = @network.selectAll(".node")
    @circles.select("circle")
      .attr("r", (d) => @get_node_width(d))
    @circles.select("text")
      .attr("font-size", (d) -> "#{d3.max([min_fontsize, d.r])}px")
      .attr("transform", (d) -> "translate(#{d.r + 1},0)")

    @circles = @circles.data(@force.nodes(), (d) -> d.id )

    node = @circles.enter()
      .append("g")
        # .attr("transform", (d) -> "translate(#{d.x},#{d.y})")
        .attr("class", (d) -> "node #{d.id}#{if d.fixed == 1 then " fixed" else ""}")
        # .attr("transform", @semantic_zoom_transform)
        .on("dblclick", @dblclick(@))
        .call(@drag)
    node
      .append("svg:circle")
        .attr("r", (d) => @get_node_width(d))
        .style("fill", (d) => @color getDomainFromJid d.id)
        .style("cursor", "pointer")
        .style("stroke", "#000")
        .style("stroke-width", "1.5px")
    node
      .append("svg:text")
        .attr("text-anchor", "left")
        # .attr("fill", "black")
        .style("pointer-events", "none")
        .attr("font-size", (d) -> d3.max([min_fontsize, d.r]) + "px")
        .attr("transform", (d) -> "translate(#{d.r + 3},0)")
        # .attr("font-weight", )
        .text((d) -> d.getText())

    @circles.exit().remove()

    @force.start()

  get_line_width: (d) ->
    d.width = ((d.count / @mode.max_line_count) * calc_width) + min_width

  get_node_width: (d) ->
    d.r = ((d.count / @mode.max_node_count) * calc_r) + min_r

  show_physical: () ->
    @mode = @physical
    @force.stop()
      .nodes([])
      .links([])
    @create_svg_elements()
    @force.stop()
      .nodes(@mode.nodes)
      .links(@mode.links)
    @limit @node_thresh, @line_thresh

  show_logical: () ->
    @mode = @logical
    @force.stop()
      .nodes([])
      .links([])
    @create_svg_elements()
    @force.stop()
      .nodes(@mode.nodes)
      .links(@mode.links)
    @limit @node_thresh, @line_thresh

  brushed: () =>
    # console.log @brush.extent()
    @re_add_logs()

  re_add_logs: () ->
    clearTimeout @redraw_timeout if @redraw_timeout
    @redraw_timeout = setTimeout(
      =>
        @force.stop()
          .nodes([])
          .links([])
        @create_svg_elements()

        @physical = {
          max_line_count: 1
          links_obj: {}
          links: []
          nodes: []
          nodes_obj: {}
          name: "physical"
        }

        @logical = {
          max_line_count: 1
          links_obj: {}
          links: []
          nodes: []
          nodes_obj: {}
          name: "logical"
        }

        switch @mode.name
          when "physical"
            @mode = @physical
          when "logical"
            @mode = @logical

        @force.stop()
          .nodes(@mode.nodes)
          .links(@mode.links)

        @create_svg_elements()

        new_logs = []
        for log in @logs
          [first, last] = @brush.extent()
          if first <= new Date(log.timestamp) <= last
            new_logs.push log

        @force.stop() if @force

        for log in new_logs
          @add_logical log
          @add_physical log

        @limit @node_thresh, @line_thresh

        @redraw_timeout = null
        return
      ,100)

  add_log: (log) ->
    @logs.push log

    if @timescale
      [first, last] = @timescale.domain()
      [ext_first, ext_last] = @brush.extent()
      new_stamp = new Date log.timestamp
      if last < new_stamp
        @timescale.domain([first, new_stamp])
        @context.select(".x.axis").call(@xAxis)
        if +last == +ext_last
          @brush.extent([ext_first, new_stamp])
        else
          @brush.extent([ext_first, ext_last])
        @brushsvg.call(@brush)
      else if new_stamp < first
        @timescale.domain([new_stamp, last])
        @context.select(".x.axis").call(@xAxis)
        if +first == +ext_first
          @brush.extent([new_stamp, ext_last])
        else
          @brush.extent([ext_first, ext_last])
        @brushsvg.call(@brush)

      if ext_first <= new_stamp <= ext_last
        @force.stop()
        @add_logical log
        @add_physical log
        @sorted_lines = false
        @sorted_nodes = false
        @limit @node_thresh, @line_thresh
    # else
    #   @add_logical log
    #   @add_physical log

  add_physical: (log) ->
    from = getBareJidFromJid log.subject
    to = getBareJidFromJid log.object
    timestamp = log.timestamp
    p = @physical

    [fNode, tNode] = @add_nodes(from, to, p, timestamp)

    if log.tags?.p2p
      link_nodes fNode, tNode, p, log.tags.p2p
      return

    # physical links
    from_domain = getDomainFromJid from
    to_domain = getDomainFromJid to

    fdNode = null
    tdNode = null

    ns = p.nodes_obj
    n = p.nodes
    if from isnt from_domain
      unless ns[from_domain]
        new_fromD = new Node from_domain, undefined,  timestamp
        n.push(ns[from_domain] = new_fromD)
      fdNode = ns[from_domain]
      fdNode.count++

    if to isnt to_domain
      unless ns[to_domain]
        new_toD = new Node to_domain, undefined,  timestamp
        n.push(ns[to_domain] = new_toD)
      tdNode = ns[to_domain]
      tdNode.count++

    max_value = +node_slider.attr "max"
    if n.length >= max_value
      max = (max_value <= +node_slider.attr "value")
      node_slider.attr "max", n.length + 1
      if max
        node_slider.attr "value", n.length + 1

    p.max_node_count = d3.max [fdNode?.count or 0, tdNode?.count or 0, p.max_node_count]
    # node_slider.attr "max", p.max_node_count + 1
    # if max
    #   node_slider.attr "value", p.max_node_count + 1

    if fdNode and tdNode
      link_nodes(fNode, fdNode, p)
      link_nodes(fdNode, tdNode, p)
      link_nodes(tdNode, tNode, p)
    else if fdNode
      link_nodes(fNode, fdNode, p)
      link_nodes(fdNode, tNode, p)
    else if tdNode
      link_nodes(fNode, tdNode, p)
      link_nodes(tdNode, tNode, p)
    else
      link_nodes(fNode, tNode, p)

  add_logical: (log) ->
    from = getBareJidFromJid log.subject
    to = getBareJidFromJid log.object
    l = @logical

    [fNode, tNode] = @add_nodes from, to, l, log.timestamp
    link_nodes fNode, tNode, l, log.tags.p2p

  # logical and physical nodes
  add_nodes: (from, to, mode, timestamp) =>
    ns = mode.nodes_obj
    n = mode.nodes
    unless ns[from]
      new_from = new Node from, undefined,  timestamp
      n.push(ns[from] = new_from)
    unless ns[to]
      new_to = new Node to, undefined,  timestamp
      n.push(ns[to] = new_to)
    fNode = ns[from]
    tNode = ns[to]
    fNode.count++
    tNode.count++

    max_value = +node_slider.attr "max"
    if n.length >= max_value
      max = (max_value <= +node_slider.attr "value")
      node_slider.attr "max", n.length + 1
      if max
        node_slider.attr "value", n.length + 1

    mode.max_node_count = d3.max [fNode.count, tNode.count, mode.max_node_count]
    # max = node_slider.attr("value") == mode.max_node_count + 1
    # node_slider.attr "max", mode.max_node_count + 1
    # if max
    #   node_slider.attr "value", mode.max_node_count + 1

    return [fNode, tNode]

  threshold: (node_thresh, line_thresh) ->
    nn = {}
    lc = 1000 / @mode.max_line_count
    nc = 1000 / @mode.max_node_count
    new_nodes = (node for node in @mode.nodes when (node.count * nc) > node_thresh and nn[node.id] = true)
    new_links = (link for link in @mode.links when nn[link.target.id] and nn[link.source.id] and (link.count * lc) > line_thresh)
    # console.log(new_links)
    @node_thresh = node_thresh
    @line_thresh = line_thresh
    @force
      .stop()
      .nodes(new_nodes)
      .links(new_links)
    @queue_redraw()

  limit: (node_limit, line_limit) ->
    @force.stop()

    nn = {}
    if node_limit isnt Infinity
      unless @sorted_nodes
        @mode.nodes.sort (a, b) -> b.count - a.count
        @sorted_nodes = true
      new_nodes = @mode.nodes[...node_limit]
      for n in new_nodes
        nn[n.id] = true
      @force.nodes(new_nodes)

    if line_limit isnt Infinity or node_limit isnt Infinity
      unless @sorted_lines
        @mode.links.sort (a, b) -> b.count - a.count
        @sorted_lines = true
      # new_links = @mode.links[...line_limit]
      new_links = []
      i = 0
      for l in @mode.links
        if nn[l.source.id] and nn[l.target.id]
          i++
          new_links.push l
          break if i >= line_limit
      @force.links(new_links)

    # console.log(new_links)
    @node_thresh = node_limit
    @line_thresh = line_limit
    @queue_redraw()


graph = null

reset_graph = () ->
  clearInterval graph_brake_id
  graph.force.stop()

  for obj in [graph.physical, graph.logical]
    obj.max_line_count = 1
    for key, value in obj.links_obj
      delete obj.links_obj[key]
    obj.links.pop() while obj.links.length
    obj.nodes.pop() while obj.nodes.length
    for key, value in graph.physical.nodes_obj
      delete obj.nodes_obj[key]

  graph.force.stop()
    .nodes(graph.mode.nodes)
    .links(graph.mode.links)

  nd = new Date()
  nd2 = new Date(5000 + (+nd))
  graph.timescale.domain([nd, nd2])
  graph.brush.extent([nd, nd2])
  graph.brushsvg.call(graph.brush)

  graph.logs = []
  graph.limit (graph.node_thresh = Infinity), (graph.line_thresh = Infinity)
  # graph_brake_id = setInterval(graph_brake graph, 300)

hexToRgb = (hex) ->
  result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex)
  return if result then {
    r: parseInt(result[1], 16)
    g: parseInt(result[2], 16)
    b: parseInt(result[3], 16) } else null

graph_brake_id = null
graph_brake = (graph) ->
  if graph.force.alpha() < 0.01
    for _ in [1..150]
      graph.force.tick()
    # graph.force.stop()
  # console.log graph.force.alpha()

node_slider = null
node_label  = null
line_slider = null
line_label  = null
min_fontsize = 12


start_graph = () ->
  graph.start()
  d3.select("button#show_physical").property "disabled", false
  d3.select("button#show_logical").property "disabled", false
  d3.select("select#viz_select").property "disabled", false
  line_slider = d3.select("input#line_thresh_slider")
    .property "disabled", false
    .attr "max", 51
    .attr "value", 51
  line_label = d3.select("label#line_limit_label")
  node_slider = d3.select("input#node_thresh_slider")
    .property "disabled", false
    .attr "max", 51
    .attr "value", 51
  node_label = d3.select("label#node_limit_label")
  d3.select("button#drawrick")
    .text("Reset Graph")
    .on "click", ->
      reset_graph()
  # graph_brake_id = setInterval(graph_brake graph, 300)
  # jsnx_start()

to_jsnx = (graph) ->
  graph = graph.force if graph.force
  jg = jsnx.Graph()
  for n in graph.nodes()
    jg.add_node(n.id, n)
   for e in graph.links()
    jg.add_edge(e.source.id, e.target.id, e)
  jg

jg = null
jsnx_start = ->
  color = d3.scale.category20()
  jsnx.draw(jg, {
    element: '#jsnx'
    height: 400
    width: 800
    with_labels: true
    # weighted: true
    # weighted_stroke: true
    # labels:k
    label_style: {
      "text-anchor": "left"
      "pointer-events": "none"
    }
    node_attr: {
      r: (d) -> d.data.count or 5
        # `d` has the properties `node`, `data` and `G`
    }
    node_style: {
      "fill": (d) -> color getDomainFromJid d.node
      "cursor": "pointer"
      "stroke": "#000"
      "stroke-width": "1.5px"
    }
    # edge_attr: {
      # "class": "link"
      # "stroke-width", (d) => @get_line_width(d)
    # }
    edge_style: {
      "stroke-width": 10
      "stroke": "#000"
    #   # "stroke-opacity": ".6"
    }
  }, false)

handleFileSelect = (evt) ->
  files = evt.target.files; # FileList object
  f = files[0]
  reader = new FileReader()

  # Closure to capture the file information.
  reader.onload = ((theFile) ->
    return (e) ->
      graph.import_logs(e.target.result)
  )(f)

  reader.readAsText(f)

export_click = () ->
  evt = document.createEvent("MouseEvents")
  evt.initMouseEvent("click", true, true, window,
    0, 0, 0, 0, 0, false, false, false, false, 0, null)
  cb = document.getElementById("export_link")
  cb.dispatchEvent(evt)

hide_exim = ->
  d3.select("#export").attr("style", "")
  d3.select("#export").style("display", "none")
  d3.select("#imex_button").on "click", show_exim
  graph.resize(graph)() if graph

show_exim = ->
  d3.select("#export").attr("style", "")
  d3.select("#export").style("display", "block")
  d3.select("#imex_button").on "click", hide_exim
  graph.resize(graph)() if graph


init_ui = ->
  graph = new Graph
  jg = jsnx.Graph()
  start_graph()

  d3.select("button#drawrick").on "click", ->
    start_graph()

  d3.select("button#jsnx_button").on "click", ->
    jg = to_jsnx graph
    console.log jg
    jsnx_start()

  d3.select("select#viz_select").on "change", ->
    switch @value
      when "viz_logical"
        graph.show_logical()
      when "viz_physical"
        graph.show_physical()

  d3.select("input#node_thresh_slider").on "change", ->
    console.log @value
    graph.limit @value, graph.line_thresh
    node_label.text "Node Limit: #{@value is @max and "All" or @value}"

  d3.select("input#line_thresh_slider").on "change", ->
    console.log @value
    graph.limit graph.node_thresh, @value
    line_label.text "Link Limit: #{@value is @max and "All" or @value}"

  d3.select("#export_button").on "click", ->
    d3.select("#export_link")
      .attr("href", "data:application/octet-stream;base64,#{btoa d3.select("#network").html()}")
      .attr("download", "network.svg")
    export_click()

  d3.select("#gexf_button").on "click", ->
    graph.export_gexf()

  d3.select("#json_export").on "click", ->
    graph.export_logs()

  d3.select("#imex_button").on "click", show_exim

  document.getElementById('file').addEventListener('change', handleFileSelect, false)
