class StatGadget extends MultiGadget
  constructor: (callback) ->
      gadgets = ["SelectorGadget", "NetworkGadget"]
      super callback, "StatGadget", gadgets

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
      console.log envelope

gadget_init = () ->
  gadget = new StatGadget(
    (envelope, message, gadget) ->
      envelope_handler envelope
      # console.log envelope
      # console.log message
      # console.log gadget
  )
  console.log "StatGadget: ", gadget
  init_ui()
  gadget.connect()

envelope_handler = (env) ->
  if env.event is "logexchange_status"
    log_handler env.message

graph_started = false
ticking = false
last_logs = {}
log_counter = 0
log_handler = (log) ->
  # if typeof log.timestamp == "string"
  #   log.timestamp = new Date log.timestamp
  # queue.push log
  # data.push log
  last_log = last_logs[log.id]
  if last_log
    tags = log.tags
    for key, tag in last_log.tags
      tags[key] = tag unless tags[key]?
  add_log log
  log_counter += 1
  last_logs[log.id] = log
  if log_counter >= 2 and window.graph_started is false
    start_graph()
    # d3.select("#startStats").property "disabled", false
    window.graph_started = true
    d3.select(window).on("resize", autoresize)
  return unless graph_started
  # tick()
  # tick() unless ticking
  # ticking = true

sessions = {}
cur_session = null
data_left_name = "percent"
data_right_name = "memory"

names = (name) ->
  {
    memory_allocated: "Allocated Memory"
    memory_used: "Used Memory"
    memory_lua: "Used Memory by Lua"
    memory_unused: "Unused Memory"
    memory_returnable: "Returnable Memory"
    cpu: "CPU Usage"
    total_s2s: "S2S (Server-to-Server) Connections"
    total_c2s: "C2S (Client-to-Server) Connections"
    total_users: "Online Users"
    total_s2sout: "Outgoing S2S Connections"
    total_s2sin: "Incoming S2S Connections"
    total_component: "Connected components"
  }[name] or name

timeSeriesChart = () ->
  width_outer = 800
  height_outer = 500
  margin = {top: 10, right: 170, bottom: 100, left: 80}
  margin2 = {top: height_outer - 70, right: margin.right, bottom: margin.bottom - 80, left: margin.left}
  width = width_outer - margin.left - margin.right
  height = height_outer - margin.top - margin.bottom
  height2 = height_outer - margin2.top - margin2.bottom

  xValue = (d) -> d.values.value
  yValue = (d) -> d.values.timestamp
  cValue = (d) -> d.name
  xScale = d3.time.scale().range([0, width])
  x2Scale = d3.time.scale().range([0, width])
  leftScale = d3.scale.linear().range([height, 0])
  rightScale = d3.scale.linear().range([height, 0])
  left2Scale = d3.scale.linear().range([height2, 0])
  right2Scale = d3.scale.linear().range([height2, 0])
  color = d3.scale.category10()
  leftAxis = d3.svg.axis().scale(leftScale).orient("left")
  rightAxis = d3.svg.axis().scale(leftScale).orient("right")
  xAxis = d3.svg.axis().scale(xScale).orient("bottom").tickSize(6, 0)
  x2Axis = d3.svg.axis().scale(x2Scale).orient("bottom").tickSize(6, 0)
  line = d3.svg.line()
  line2 = d3.svg.line()
  things = null
  thing = null
  focus = null
  context = null

  brushed = ->
    xScale.domain(if brush.empty() then x2Scale.domain() else brush.extent())
    # focus.select(".line").attr("d", line)
    focus.selectAll(".left_line").attr("d", (d) -> left_line(d.values))
    focus.selectAll(".right_line").attr("d", (d) -> right_line(d.values))
    focus.select(".x.axis").call(xAxis)

  brush = d3.svg.brush().x(x2Scale).on("brush", brushed)

  chart = (selection) ->
    selection.each (data) ->

      data_left = data[data_left_name]
      data_right = data[data_right_name]

      color.domain(d3.keys(data_left[0]).filter((key) -> key isnt "timestamp"))

      left_things = things = color.domain().map((name) ->
        { name: names(name), values: data_left.map((d) ->
          {timestamp: d.timestamp, value: +d[name]}
        )}
      )

      right_things = color.domain().map((name) ->
        { name: names(name), values: data_left.map((d) ->
          {timestamp: d.timestamp, value: +d[name]}
        )}
      )

      xScale.domain(d3.extent(data_left, (d) -> d.timestamp))
      leftScale.domain([0, d3.max(left_things, (c) -> d3.max(c.values, (v) -> v.value))])
      rightScale.domain([0, d3.max(right_things, (c) -> d3.max(c.values, (v) -> v.value))])

      x2Scale.domain(xScale.domain())
      left2Scale.domain(leftScale.domain())
      right2Scale.domain(rightScale.domain())

      left_line
        .interpolate("basis")
        .x((d) -> xScale d.timestamp)
        .y((d) -> leftScale d.value)

      right_line
        .interpolate("basis")
        .x((d) -> xScale d.timestamp)
        .y((d) -> rightScale d.value)

      left_line2
        .interpolate("basis")
        .x((d) -> x2Scale d.timestamp)
        .y((d) -> left2Scale d.value)

      right_line2
        .interpolate("basis")
        .x((d) -> x2Scale d.timestamp)
        .y((d) -> right2Scale d.value)

      # create the svg.
      svg = d3.select("p").append("svg")
          .attr("width", width + margin.left + margin.right)
          .attr("height", height + margin.top + margin.bottom)

      svg.append("defs").append("clipPath")
          .attr("id", "clip")
        .append("rect")
          .attr("x", "0")
          .attr("y", "0")
          .attr("width", width)
          .attr("height", height)

      focus = svg.append("g")
        .attr("class", "focus")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

      context = svg.append("g")
        .attr("class", "context")
        .attr("transform", "translate(#{margin2.left},#{margin2.top})")

      focus.append("g").attr("class", "x axis")
      context.append("g").attr("class", "x axis")

      focus.append("g").attr("class", "left axis")
      focus.append("g").attr("class", "right axis")

      focus_thing = focus.selectAll(".thing")
          .data(things)
        .enter().append("g")
          .attr("class", "thing")

      # Update the line path.
      focus_thing.append("path")
        .attr("class", "line")
        .attr("clip-path", 'url("#clip")')
        .attr("d", (d) -> line d.values )
        .attr("data-legend", (d) -> d.name)
        .attr("data-legend-color", (d) -> color d.name)
        .style("stroke", (d) -> color d.name )

      # focus_thing.append("text")
      #   .datum((d) -> name: d.name, value: d.values[d.values.length - 1])
      #   .attr("transform", (d) -> "translate(#{xScale d.value.timestamp},#{leftScale d.value.value})")
      #   .attr("x", 3)
      #   .text((d) -> d.name)

      # Update the x-axis.
      focus.select(".x.axis")
        .attr("transform", "translate(0,#{height})")
        .call(xAxis)

      context_thing = context.selectAll(".thing")
          .data(things)
        .enter().append("g")
          .attr("class", "thing")

      # Update the line path.
      context_thing.append("path")
        .attr("class", "line")
        .attr("d", (d) -> line2(d.values))
        .style("stroke", (d) -> color(d.name))

      context.select(".x.axis")
        .attr("transform", "translate(0,#{height2})")
        .call(x2Axis)

      context.append("g")
          .attr("class", "x brush")
          .call(brush)
        .selectAll("rect")
          .attr("y", -6)
          .attr("height", height2 + 7)

      # Update the x-axis.
      focus.select(".left.axis")
        # .attr("transform", "translate(#{xScale.range()[0]}, 0)")
        .call(leftAxis)

      # Update the x-axis.
      focus.select(".right.axis")
        .attr("transform", "translate(#{width_outer}, 0)")
        .call(rightAxis)

      legend = svg.append("g")
        .attr("class","legend")
        .attr("transform","translate(#{width_outer - margin.right + 20},#{margin.top + 20})")
        .style("font-size","12px")
        .call(d3.legend)

  chart.redraw = (data) ->
    data_left = data[data_left_name]
    data_right = data[data_right_name]

    color.domain(d3.keys(data_left[0]).filter((key) -> key isnt "timestamp"))

    left_things = things = color.domain().map((name) ->
      { name: names(name), values: data_left.map((d) ->
          {timestamp: d.timestamp, value: +d[name]}
      )}
    )

    xScale.domain(d3.extent(data_left, (d) -> d.timestamp))
    leftScale.domain([0, d3.max(left_things, (c) -> d3.max(c.values, (v) -> v.value))])
    rightScale.domain([0, d3.max(right_things, (c) -> d3.max(c.values, (v) -> v.value))])

    x2Scale.domain(xScale.domain())
    left2Scale.domain(leftScale.domain())

    xScale.domain(if brush.empty() then x2Scale.domain() else brush.extent())


    focus.selectAll(".thing")
        .data(things)

    focus.selectAll(".line")
        .data(things)
        .attr("d", (d) -> line(d.values))
      .transition()
        .duration(2000)
        .ease("linear")
        # .attr("transform", "translate(" + x(-1) + ",0)")

    context.selectAll(".thing")
        .data(things)
    context.selectAll(".line")
        .data(things)
        .attr("d", (d) -> line2(d.values))
      .transition()
        .duration(2000)
        .ease("linear")

    focus.select(".x.axis").call(xAxis)
    context.select(".x.axis").call(x2Axis)

    focus.select(".y.axis").call(leftAxis)


  chart.margin = (value) ->
    return margin unless value
    margin = value
    chart

  chart.width = (value) ->
    return width unless value
    width = value
    chart

  chart.height = (value) ->
    return height unless value
    height = value
    chart

  chart.x = (value) ->
    return xValue unless value
    xValue = value
    return chart

  chart.y = (value) ->
    return yValue unless value
    yValue = value
    return chart

  chart.updateData = (data) ->
    # color.domain(d3.keys(data))
    # Update the x-scale.
    xScale
      .domain(d3.extent(data, (d) -> d.timestamp))
      .range([0, width - margin.left - margin.right])

    things = color.domain().map((name) ->
      { name: name, values: data.map((d) ->
          {timestamp: d.timestamp, value: +d[name]}
      )}
    )

    # Update the y-scale.
    leftScale
      .domain([
        # d3.min(things, (c) -> d3.min(c.values, (v) -> v.value ) ),
        0,
        d3.max(things, (c) -> d3.max(c.values, (v) -> v.value ) )
      ])
      .range([height - margin.top - margin.bottom, 0])

    svg = d3.select("svg")
    t = svg.selectAll(".thing")
    t
      .data(things)
      .select(".line")
      .attr("class", "line")
      .attr("d", (d) -> line(d.values))

    # t.select("text")
    #   .datum((d) -> name: d.name, value: d.values[d.values.length - 1])
    #   .attr("transform", (d) -> "translate(#{xScale d.value.timestamp},#{leftScale d.value.value})")
    #   .attr("x", 3)

    svg.select(".x.axis")
      .attr("transform", "translate(0,#{leftScale.range()[0]})")
      .call(xAxis)

    svg.select(".y.axis")
      .call(leftAxis)

  chart.updateDimensions = () ->
    xScale.range([0, width - margin.left - margin.right])
    leftScale.range([height - margin.top - margin.bottom, 0])

  chart.getConfig = ->
    xValue: xValue
    yValue: yValue
    cValue: cValue
    xScale: xScale
    leftScale: leftScale
    color: color
    leftAxis: leftAxis
    xAxis: xAxis
    thing: thing
    things: things

  chart

chart = null


draw_chart = () ->
  chart = timeSeriesChart()
  d3.select("#example")
    .datum(cur_session)
    .call(chart)

redraw = () ->
  chart.redraw d3.select("#example").datum(cur_session)

sessions = {}

palette = new Rickshaw.Color.Palette()
scales = {
  percent: d3.scale.linear().domain([0, 100]).nice()
  memory: d3.scale.linear().nice()
  numbers: d3.scale.linear().nice()
}

scale_select = (name) ->
  return scales.memory if name.startsWith "memory_"
  return scales.percent if name in ["cpu"]
  return scales.numbers

add_log = (log) ->
  new_session = false
  session = sessions[log.id]
  unless session
    session = sessions[log.id] = {}
    new_session = true

  stamp = Math.floor(new Date(log.timestamp).getTime() / 1000)

  for name, tag of log.tags
    if name in ["time", "up_since"]
      continue
    s = session[name] or session[name] = {
      color: palette.color()
      data: []
      # name: "#{log.id[0..2]}…: #{names name}"
      name: "#{log.subject} - #{log.id}: #{names name}"
      scale: scale_select name
      min: +tag.value
      max: +tag.value
    }
    s.data.push {x: stamp, y: +tag.value}
  if chart.graph
    if new_session
      set_series("memory", "numbers", "percent")
      start_graph()
    else
      chart.update()

series_active = []

set_series = (type1, type2, type3) ->
  series_active = []
  scales_active = [scales[type1], scales[type2]]
  scales_active.push scales[type3] if type3
  for id, ses of sessions
    for name, s of ses
      series_active.push s if s.scale in scales_active


resize = (x, y) ->
  height = y or chart.graph.height
  width = x or chart.graph.width
  left_width = 40
  right_width = 40
  chart_width = width - left_width - right_width - 2
  d3.select("#chart")
      .style("width", chart_width)
    .select("svg")
        .attr("width", chart_width)
        .attr("height", height)
  d3.select("#chart_container")
    .style("width", width)
    .style("height", height + 70)

  # d3.select("#axis0").style("width", left_width)
  # d3.select("#axis1").style("width", right_width)

  d3.select("#preview")
        # .style("left", left_width - 2)
      #   .style("width", chart_width)
    .select("svg.rickshaw_range_slider_preview")
    #     .attr("width", chart_width)
        # .style("position", "relative")
        .style("left", "40px")

  chart.graph.configure({height: y, width: chart_width})
  chart.config.slider.configure(width: chart_width)
  chart.graph.update()

autoresize = ->
  x = window.innerWidth
  y = window.innerHeight - parseInt(d3.select("#legend.rickshaw_legend").style("height")) - 100
  resize(x, y)


rescale = () ->
  mem_min = num_min = Number.MAX_VALUE
  mem_max = num_max = Number.MIN_VALUE
  for s, i in series_active
    sc = s.scale
    if sc is scales.memory
      minmax  = d3.extent(s.data, (p) -> p.y)
      mem_min = minmax[0] if minmax[0] < mem_min
      mem_max = minmax[1] if minmax[1] > mem_max
    else if sc is scales.numbers
      minmax  = d3.extent(s.data, (p) -> p.y)
      num_min = minmax[0] if minmax[0] < num_min
      num_max = minmax[1] if minmax[1] > num_max

  scales.memory.domain([0, mem_max * 1.10])
  scales.numbers.domain([0, (num_max + 2) * 1.2])
  chart.graph.update()

rick = () ->
  height = 300
  width = 800
  left_width = 40
  right_width = 40
  chart_width = width - left_width - right_width - 2
  d3.select("#chart_container").style("width", width)
  d3.select("#chart").style("width", chart_width)
  d3.select("#axis0").style("width", left_width)
  d3.select("#axis1").style("width", right_width)
  # d3.select("#preview").style("left", left_width - 2)

  mem_min = num_min = Number.MAX_VALUE
  mem_max = num_max = Number.MIN_VALUE
  for s, i in series_active
    sc = s.scale
    if sc is scales.memory
      minmax  = d3.extent(s.data, (p) -> p.y)
      mem_min = minmax[0] if minmax[0] < mem_min
      mem_max = minmax[1] if minmax[1] > mem_max
    else if sc is scales.numbers
      minmax  = d3.extent(s.data, (p) -> p.y)
      num_min = minmax[0] if minmax[0] < num_min
      num_max = minmax[1] if minmax[1] > num_max

  scales.memory.domain([0, mem_max * 1.10])
  scales.numbers.domain([0, (num_max + 2) * 1.2])

  graph = new Rickshaw.Graph({
    element: document.getElementById("chart")
    renderer: 'line'
    stack: false
    width: chart_width
    height: height
    interpolation: "linear"
    series: series_active
  })

  leftAxis = new Rickshaw.Graph.Axis.Y.Scaled({
    element: document.getElementById('axis0')
    graph: graph
    height: height + 20
    orientation: 'left'
    scale: scales.memory
    tickFormat: Rickshaw.Fixtures.Number.formatKMBT
  })

  rightAxis = new Rickshaw.Graph.Axis.Y.Scaled({
    element: document.getElementById('axis1')
    graph: graph
    height: height + 20
    grid: false
    orientation: 'right'
    scale: scales.numbers
    tickFormat: Rickshaw.Fixtures.Number.formatKMBT
  })

  invAxis = new Rickshaw.Graph.Axis.Y.Scaled({
    element: document.getElementById('axis2')
    graph: graph
    height: height + 20
    grid: false
    orientation: 'left'
    scale: scales.percent
    tickFormat: Rickshaw.Fixtures.Number.formatKMBT
  })

  xAxis = new Rickshaw.Graph.Axis.Time({
    graph: graph
  })

  hoverDetail = new Rickshaw.Graph.HoverDetail({
    graph: graph
  })

  legend = new Rickshaw.Graph.Legend({
    graph: graph
    element: document.getElementById('legend')
  })

  shelving = new Rickshaw.Graph.Behavior.Series.Toggle({
    graph: graph
    legend: legend
  })

  order = new Rickshaw.Graph.Behavior.Series.Order({
    graph: graph
    legend: legend
  })

  highlighter = new Rickshaw.Graph.Behavior.Series.Highlight({
    graph: graph
    legend: legend
  })

  graph.render()

  ticksTreatment = 'glow'

  slider = new Rickshaw.Graph.RangeSlider.Preview({
    graph: graph
    height: 40
    width: chart_width
    element: document.getElementById('preview')
  })

  # d3.select("#preview").select("svg")
    # .attr("width", chart_width)
    # .style("position", "relative")
    # .style("left", "-40px")

  # previewXAxis = new Rickshaw.Graph.Axis.Time({
  #   graph: slider
  #   element: document.getElementById('slider')
  #   timeFixture: new Rickshaw.Fixtures.Time.Local()
  #   ticksTreatment: ticksTreatment
  # })
  #
  # previewXAxis.render()

  return {
    graph: graph
    slider: slider
    highlighter: highlighter
    order: order
    shelving: shelving
    legend: legend
    leftAxis: leftAxis
    rightAxis: rightAxis
  }

chart = {}

start_graph = ->
  chart = {}
  d3.select("#waiting").style("display", "none")
  set_series("memory", "numbers", "percent")
  d3.select("#chart_container").html(
    """
  <div id="chart_container">
    <div id="axis0"></div>
    <div id="chart"></div>
    <div id="axis1"></div>
    <div style="display: none;" id="axis2"></div>
    <div id="preview"></div>
  </div>
    """
  )
  d3.select("#legend").html("").attr("class", "").attr("style", "")
  chart.config = rick()
  chart.graph = chart.config.graph
  chart.update = (x, y) ->
    if x and y
      resize(x, y)
    rescale()
  resize(599, 299)
  autoresize()

init_ui = ->
  d3.select("button#startStats").on "click", ->
    if chart?.redraw?
      chart.redraw(cur_session)
    else
      draw_chart()
    window.graph_started = true

  d3.select("button#redrawStats").on "click", ->
    chart.updateData(cur_session)

  d3.select("button#drawrick").on "click", ->
    if not chart.graph
      start_graph()
    else
      chart.update()

