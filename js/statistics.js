// Generated by CoffeeScript 1.7.1
var StatGadget, add_log, autoresize, chart, cur_session, data_left_name, data_right_name, draw_chart, envelope_handler, gadget_init, graph_started, init_ui, last_logs, log_counter, log_handler, names, palette, redraw, rescale, resize, rick, scale_select, scales, series_active, sessions, set_series, start_graph, ticking, timeSeriesChart,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

StatGadget = (function(_super) {
  __extends(StatGadget, _super);

  function StatGadget(callback) {
    var gadgets;
    gadgets = ["SelectorGadget", "NetworkGadget"];
    StatGadget.__super__.constructor.call(this, callback, "StatGadget", gadgets);
  }

  StatGadget.prototype.init = function() {
    var env;
    env = new Envelope("enter");
    return env.publish();
  };

  StatGadget.prototype.openAppCallback = function(envelope, message) {
    if (/StatGadget.xml$/.test(envelope.sender) || /SelectorGadget.xml$/.test(envelope.sender) || /explorerGadget.xml$/.test(envelope.sender)) {
      switch (envelope.event) {
        case "error":
          return console.log("Received error message from statistics gadget but the type is unknown: " + envelope.message["http://purl.org/dc/terms/type"]);
        case "enter":
          return console.log("OpenApp: entered", envelope, message);
        case "exit":
          return console.log("OpenApp: exited");
        default:
          return console.log("Received unknown event message from gadget: " + envelope.sender + " Message: " + envelope.event);
      }
    } else {
      console.log("Received (MasterGadget) unknown event message from unknown sender: " + envelope.sender + " Event: " + envelope.event + " Message: " + envelope.message);
      return console.log(envelope);
    }
  };

  return StatGadget;

})(MultiGadget);

gadget_init = function() {
  var gadget;
  gadget = new StatGadget(function(envelope, message, gadget) {
    return envelope_handler(envelope);
  });
  console.log("StatGadget: ", gadget);
  init_ui();
  return gadget.connect();
};

envelope_handler = function(env) {
  if (env.event === "logexchange_status") {
    return log_handler(env.message);
  }
};

graph_started = false;

ticking = false;

last_logs = {};

log_counter = 0;

log_handler = function(log) {
  var key, last_log, tag, tags, _i, _len, _ref;
  last_log = last_logs[log.id];
  if (last_log) {
    tags = log.tags;
    _ref = last_log.tags;
    for (tag = _i = 0, _len = _ref.length; _i < _len; tag = ++_i) {
      key = _ref[tag];
      if (tags[key] == null) {
        tags[key] = tag;
      }
    }
  }
  add_log(log);
  log_counter += 1;
  last_logs[log.id] = log;
  if (log_counter >= 2 && window.graph_started === false) {
    start_graph();
    window.graph_started = true;
    d3.select(window).on("resize", autoresize);
  }
  if (!graph_started) {

  }
};

sessions = {};

cur_session = null;

data_left_name = "percent";

data_right_name = "memory";

names = function(name) {
  return {
    memory_allocated: "Allocated Memory",
    memory_used: "Used Memory",
    memory_lua: "Used Memory by Lua",
    memory_unused: "Unused Memory",
    memory_returnable: "Returnable Memory",
    cpu: "CPU Usage",
    total_s2s: "S2S (Server-to-Server) Connections",
    total_c2s: "C2S (Client-to-Server) Connections",
    total_users: "Online Users",
    total_s2sout: "Outgoing S2S Connections",
    total_s2sin: "Incoming S2S Connections",
    total_component: "Connected components"
  }[name] || name;
};

timeSeriesChart = function() {
  var brush, brushed, cValue, chart, color, context, focus, height, height2, height_outer, left2Scale, leftAxis, leftScale, line, line2, margin, margin2, right2Scale, rightAxis, rightScale, thing, things, width, width_outer, x2Axis, x2Scale, xAxis, xScale, xValue, yValue;
  width_outer = 800;
  height_outer = 500;
  margin = {
    top: 10,
    right: 170,
    bottom: 100,
    left: 80
  };
  margin2 = {
    top: height_outer - 70,
    right: margin.right,
    bottom: margin.bottom - 80,
    left: margin.left
  };
  width = width_outer - margin.left - margin.right;
  height = height_outer - margin.top - margin.bottom;
  height2 = height_outer - margin2.top - margin2.bottom;
  xValue = function(d) {
    return d.values.value;
  };
  yValue = function(d) {
    return d.values.timestamp;
  };
  cValue = function(d) {
    return d.name;
  };
  xScale = d3.time.scale().range([0, width]);
  x2Scale = d3.time.scale().range([0, width]);
  leftScale = d3.scale.linear().range([height, 0]);
  rightScale = d3.scale.linear().range([height, 0]);
  left2Scale = d3.scale.linear().range([height2, 0]);
  right2Scale = d3.scale.linear().range([height2, 0]);
  color = d3.scale.category10();
  leftAxis = d3.svg.axis().scale(leftScale).orient("left");
  rightAxis = d3.svg.axis().scale(leftScale).orient("right");
  xAxis = d3.svg.axis().scale(xScale).orient("bottom").tickSize(6, 0);
  x2Axis = d3.svg.axis().scale(x2Scale).orient("bottom").tickSize(6, 0);
  line = d3.svg.line();
  line2 = d3.svg.line();
  things = null;
  thing = null;
  focus = null;
  context = null;
  brushed = function() {
    xScale.domain(brush.empty() ? x2Scale.domain() : brush.extent());
    focus.selectAll(".left_line").attr("d", function(d) {
      return left_line(d.values);
    });
    focus.selectAll(".right_line").attr("d", function(d) {
      return right_line(d.values);
    });
    return focus.select(".x.axis").call(xAxis);
  };
  brush = d3.svg.brush().x(x2Scale).on("brush", brushed);
  chart = function(selection) {
    return selection.each(function(data) {
      var context_thing, data_left, data_right, focus_thing, left_things, legend, right_things, svg;
      data_left = data[data_left_name];
      data_right = data[data_right_name];
      color.domain(d3.keys(data_left[0]).filter(function(key) {
        return key !== "timestamp";
      }));
      left_things = things = color.domain().map(function(name) {
        return {
          name: names(name),
          values: data_left.map(function(d) {
            return {
              timestamp: d.timestamp,
              value: +d[name]
            };
          })
        };
      });
      right_things = color.domain().map(function(name) {
        return {
          name: names(name),
          values: data_left.map(function(d) {
            return {
              timestamp: d.timestamp,
              value: +d[name]
            };
          })
        };
      });
      xScale.domain(d3.extent(data_left, function(d) {
        return d.timestamp;
      }));
      leftScale.domain([
        0, d3.max(left_things, function(c) {
          return d3.max(c.values, function(v) {
            return v.value;
          });
        })
      ]);
      rightScale.domain([
        0, d3.max(right_things, function(c) {
          return d3.max(c.values, function(v) {
            return v.value;
          });
        })
      ]);
      x2Scale.domain(xScale.domain());
      left2Scale.domain(leftScale.domain());
      right2Scale.domain(rightScale.domain());
      left_line.interpolate("basis").x(function(d) {
        return xScale(d.timestamp);
      }).y(function(d) {
        return leftScale(d.value);
      });
      right_line.interpolate("basis").x(function(d) {
        return xScale(d.timestamp);
      }).y(function(d) {
        return rightScale(d.value);
      });
      left_line2.interpolate("basis").x(function(d) {
        return x2Scale(d.timestamp);
      }).y(function(d) {
        return left2Scale(d.value);
      });
      right_line2.interpolate("basis").x(function(d) {
        return x2Scale(d.timestamp);
      }).y(function(d) {
        return right2Scale(d.value);
      });
      svg = d3.select("p").append("svg").attr("width", width + margin.left + margin.right).attr("height", height + margin.top + margin.bottom);
      svg.append("defs").append("clipPath").attr("id", "clip").append("rect").attr("x", "0").attr("y", "0").attr("width", width).attr("height", height);
      focus = svg.append("g").attr("class", "focus").attr("transform", "translate(" + margin.left + "," + margin.top + ")");
      context = svg.append("g").attr("class", "context").attr("transform", "translate(" + margin2.left + "," + margin2.top + ")");
      focus.append("g").attr("class", "x axis");
      context.append("g").attr("class", "x axis");
      focus.append("g").attr("class", "left axis");
      focus.append("g").attr("class", "right axis");
      focus_thing = focus.selectAll(".thing").data(things).enter().append("g").attr("class", "thing");
      focus_thing.append("path").attr("class", "line").attr("clip-path", 'url("#clip")').attr("d", function(d) {
        return line(d.values);
      }).attr("data-legend", function(d) {
        return d.name;
      }).attr("data-legend-color", function(d) {
        return color(d.name);
      }).style("stroke", function(d) {
        return color(d.name);
      });
      focus.select(".x.axis").attr("transform", "translate(0," + height + ")").call(xAxis);
      context_thing = context.selectAll(".thing").data(things).enter().append("g").attr("class", "thing");
      context_thing.append("path").attr("class", "line").attr("d", function(d) {
        return line2(d.values);
      }).style("stroke", function(d) {
        return color(d.name);
      });
      context.select(".x.axis").attr("transform", "translate(0," + height2 + ")").call(x2Axis);
      context.append("g").attr("class", "x brush").call(brush).selectAll("rect").attr("y", -6).attr("height", height2 + 7);
      focus.select(".left.axis").call(leftAxis);
      focus.select(".right.axis").attr("transform", "translate(" + width_outer + ", 0)").call(rightAxis);
      return legend = svg.append("g").attr("class", "legend").attr("transform", "translate(" + (width_outer - margin.right + 20) + "," + (margin.top + 20) + ")").style("font-size", "12px").call(d3.legend);
    });
  };
  chart.redraw = function(data) {
    var data_left, data_right, left_things;
    data_left = data[data_left_name];
    data_right = data[data_right_name];
    color.domain(d3.keys(data_left[0]).filter(function(key) {
      return key !== "timestamp";
    }));
    left_things = things = color.domain().map(function(name) {
      return {
        name: names(name),
        values: data_left.map(function(d) {
          return {
            timestamp: d.timestamp,
            value: +d[name]
          };
        })
      };
    });
    xScale.domain(d3.extent(data_left, function(d) {
      return d.timestamp;
    }));
    leftScale.domain([
      0, d3.max(left_things, function(c) {
        return d3.max(c.values, function(v) {
          return v.value;
        });
      })
    ]);
    rightScale.domain([
      0, d3.max(right_things, function(c) {
        return d3.max(c.values, function(v) {
          return v.value;
        });
      })
    ]);
    x2Scale.domain(xScale.domain());
    left2Scale.domain(leftScale.domain());
    xScale.domain(brush.empty() ? x2Scale.domain() : brush.extent());
    focus.selectAll(".thing").data(things);
    focus.selectAll(".line").data(things).attr("d", function(d) {
      return line(d.values);
    }).transition().duration(2000).ease("linear");
    context.selectAll(".thing").data(things);
    context.selectAll(".line").data(things).attr("d", function(d) {
      return line2(d.values);
    }).transition().duration(2000).ease("linear");
    focus.select(".x.axis").call(xAxis);
    context.select(".x.axis").call(x2Axis);
    return focus.select(".y.axis").call(leftAxis);
  };
  chart.margin = function(value) {
    if (!value) {
      return margin;
    }
    margin = value;
    return chart;
  };
  chart.width = function(value) {
    if (!value) {
      return width;
    }
    width = value;
    return chart;
  };
  chart.height = function(value) {
    if (!value) {
      return height;
    }
    height = value;
    return chart;
  };
  chart.x = function(value) {
    if (!value) {
      return xValue;
    }
    xValue = value;
    return chart;
  };
  chart.y = function(value) {
    if (!value) {
      return yValue;
    }
    yValue = value;
    return chart;
  };
  chart.updateData = function(data) {
    var svg, t;
    xScale.domain(d3.extent(data, function(d) {
      return d.timestamp;
    })).range([0, width - margin.left - margin.right]);
    things = color.domain().map(function(name) {
      return {
        name: name,
        values: data.map(function(d) {
          return {
            timestamp: d.timestamp,
            value: +d[name]
          };
        })
      };
    });
    leftScale.domain([
      0, d3.max(things, function(c) {
        return d3.max(c.values, function(v) {
          return v.value;
        });
      })
    ]).range([height - margin.top - margin.bottom, 0]);
    svg = d3.select("svg");
    t = svg.selectAll(".thing");
    t.data(things).select(".line").attr("class", "line").attr("d", function(d) {
      return line(d.values);
    });
    svg.select(".x.axis").attr("transform", "translate(0," + (leftScale.range()[0]) + ")").call(xAxis);
    return svg.select(".y.axis").call(leftAxis);
  };
  chart.updateDimensions = function() {
    xScale.range([0, width - margin.left - margin.right]);
    return leftScale.range([height - margin.top - margin.bottom, 0]);
  };
  chart.getConfig = function() {
    return {
      xValue: xValue,
      yValue: yValue,
      cValue: cValue,
      xScale: xScale,
      leftScale: leftScale,
      color: color,
      leftAxis: leftAxis,
      xAxis: xAxis,
      thing: thing,
      things: things
    };
  };
  return chart;
};

chart = null;

draw_chart = function() {
  chart = timeSeriesChart();
  return d3.select("#example").datum(cur_session).call(chart);
};

redraw = function() {
  return chart.redraw(d3.select("#example").datum(cur_session));
};

sessions = {};

palette = new Rickshaw.Color.Palette();

scales = {
  percent: d3.scale.linear().domain([0, 100]).nice(),
  memory: d3.scale.linear().nice(),
  numbers: d3.scale.linear().nice()
};

scale_select = function(name) {
  if (name.startsWith("memory_")) {
    return scales.memory;
  }
  if (name === "cpu") {
    return scales.percent;
  }
  return scales.numbers;
};

add_log = function(log) {
  var name, new_session, s, session, stamp, tag, _ref;
  new_session = false;
  session = sessions[log.id];
  if (!session) {
    session = sessions[log.id] = {};
    new_session = true;
  }
  stamp = Math.floor(new Date(log.timestamp).getTime() / 1000);
  _ref = log.tags;
  for (name in _ref) {
    tag = _ref[name];
    if (name === "time" || name === "up_since") {
      continue;
    }
    s = session[name] || (session[name] = {
      color: palette.color(),
      data: [],
      name: "" + log.subject + " - " + log.id + ": " + (names(name)),
      scale: scale_select(name),
      min: +tag.value,
      max: +tag.value
    });
    s.data.push({
      x: stamp,
      y: +tag.value
    });
  }
  if (chart.graph) {
    if (new_session) {
      set_series("memory", "numbers", "percent");
      return start_graph();
    } else {
      return chart.update();
    }
  }
};

series_active = [];

set_series = function(type1, type2, type3) {
  var id, name, s, scales_active, ses, _results;
  series_active = [];
  scales_active = [scales[type1], scales[type2]];
  if (type3) {
    scales_active.push(scales[type3]);
  }
  _results = [];
  for (id in sessions) {
    ses = sessions[id];
    _results.push((function() {
      var _ref, _results1;
      _results1 = [];
      for (name in ses) {
        s = ses[name];
        if (_ref = s.scale, __indexOf.call(scales_active, _ref) >= 0) {
          _results1.push(series_active.push(s));
        } else {
          _results1.push(void 0);
        }
      }
      return _results1;
    })());
  }
  return _results;
};

resize = function(x, y) {
  var chart_width, height, left_width, right_width, width;
  height = y || chart.graph.height;
  width = x || chart.graph.width;
  left_width = 40;
  right_width = 40;
  chart_width = width - left_width - right_width - 2;
  d3.select("#chart").style("width", chart_width).select("svg").attr("width", chart_width).attr("height", height);
  d3.select("#chart_container").style("width", width).style("height", height + 70);
  d3.select("#preview").select("svg.rickshaw_range_slider_preview").style("left", "40px");
  chart.graph.configure({
    height: y,
    width: chart_width
  });
  chart.config.slider.configure({
    width: chart_width
  });
  return chart.graph.update();
};

autoresize = function() {
  var x, y;
  x = window.innerWidth;
  y = window.innerHeight - parseInt(d3.select("#legend.rickshaw_legend").style("height")) - 100;
  return resize(x, y);
};

rescale = function() {
  var i, mem_max, mem_min, minmax, num_max, num_min, s, sc, _i, _len;
  mem_min = num_min = Number.MAX_VALUE;
  mem_max = num_max = Number.MIN_VALUE;
  for (i = _i = 0, _len = series_active.length; _i < _len; i = ++_i) {
    s = series_active[i];
    sc = s.scale;
    if (sc === scales.memory) {
      minmax = d3.extent(s.data, function(p) {
        return p.y;
      });
      if (minmax[0] < mem_min) {
        mem_min = minmax[0];
      }
      if (minmax[1] > mem_max) {
        mem_max = minmax[1];
      }
    } else if (sc === scales.numbers) {
      minmax = d3.extent(s.data, function(p) {
        return p.y;
      });
      if (minmax[0] < num_min) {
        num_min = minmax[0];
      }
      if (minmax[1] > num_max) {
        num_max = minmax[1];
      }
    }
  }
  scales.memory.domain([0, mem_max * 1.10]);
  scales.numbers.domain([0, (num_max + 2) * 1.2]);
  return chart.graph.update();
};

rick = function() {
  var chart_width, graph, height, highlighter, hoverDetail, i, invAxis, leftAxis, left_width, legend, mem_max, mem_min, minmax, num_max, num_min, order, rightAxis, right_width, s, sc, shelving, slider, ticksTreatment, width, xAxis, _i, _len;
  height = 300;
  width = 800;
  left_width = 40;
  right_width = 40;
  chart_width = width - left_width - right_width - 2;
  d3.select("#chart_container").style("width", width);
  d3.select("#chart").style("width", chart_width);
  d3.select("#axis0").style("width", left_width);
  d3.select("#axis1").style("width", right_width);
  mem_min = num_min = Number.MAX_VALUE;
  mem_max = num_max = Number.MIN_VALUE;
  for (i = _i = 0, _len = series_active.length; _i < _len; i = ++_i) {
    s = series_active[i];
    sc = s.scale;
    if (sc === scales.memory) {
      minmax = d3.extent(s.data, function(p) {
        return p.y;
      });
      if (minmax[0] < mem_min) {
        mem_min = minmax[0];
      }
      if (minmax[1] > mem_max) {
        mem_max = minmax[1];
      }
    } else if (sc === scales.numbers) {
      minmax = d3.extent(s.data, function(p) {
        return p.y;
      });
      if (minmax[0] < num_min) {
        num_min = minmax[0];
      }
      if (minmax[1] > num_max) {
        num_max = minmax[1];
      }
    }
  }
  scales.memory.domain([0, mem_max * 1.10]);
  scales.numbers.domain([0, (num_max + 2) * 1.2]);
  graph = new Rickshaw.Graph({
    element: document.getElementById("chart"),
    renderer: 'line',
    stack: false,
    width: chart_width,
    height: height,
    interpolation: "linear",
    series: series_active
  });
  leftAxis = new Rickshaw.Graph.Axis.Y.Scaled({
    element: document.getElementById('axis0'),
    graph: graph,
    height: height + 20,
    orientation: 'left',
    scale: scales.memory,
    tickFormat: Rickshaw.Fixtures.Number.formatKMBT
  });
  rightAxis = new Rickshaw.Graph.Axis.Y.Scaled({
    element: document.getElementById('axis1'),
    graph: graph,
    height: height + 20,
    grid: false,
    orientation: 'right',
    scale: scales.numbers,
    tickFormat: Rickshaw.Fixtures.Number.formatKMBT
  });
  invAxis = new Rickshaw.Graph.Axis.Y.Scaled({
    element: document.getElementById('axis2'),
    graph: graph,
    height: height + 20,
    grid: false,
    orientation: 'left',
    scale: scales.percent,
    tickFormat: Rickshaw.Fixtures.Number.formatKMBT
  });
  xAxis = new Rickshaw.Graph.Axis.Time({
    graph: graph
  });
  hoverDetail = new Rickshaw.Graph.HoverDetail({
    graph: graph
  });
  legend = new Rickshaw.Graph.Legend({
    graph: graph,
    element: document.getElementById('legend')
  });
  shelving = new Rickshaw.Graph.Behavior.Series.Toggle({
    graph: graph,
    legend: legend
  });
  order = new Rickshaw.Graph.Behavior.Series.Order({
    graph: graph,
    legend: legend
  });
  highlighter = new Rickshaw.Graph.Behavior.Series.Highlight({
    graph: graph,
    legend: legend
  });
  graph.render();
  ticksTreatment = 'glow';
  slider = new Rickshaw.Graph.RangeSlider.Preview({
    graph: graph,
    height: 40,
    width: chart_width,
    element: document.getElementById('preview')
  });
  return {
    graph: graph,
    slider: slider,
    highlighter: highlighter,
    order: order,
    shelving: shelving,
    legend: legend,
    leftAxis: leftAxis,
    rightAxis: rightAxis
  };
};

chart = {};

start_graph = function() {
  chart = {};
  d3.select("#waiting").style("display", "none");
  set_series("memory", "numbers", "percent");
  d3.select("#chart_container").html("<div id=\"chart_container\">\n  <div id=\"axis0\"></div>\n  <div id=\"chart\"></div>\n  <div id=\"axis1\"></div>\n  <div style=\"display: none;\" id=\"axis2\"></div>\n  <div id=\"preview\"></div>\n</div>");
  d3.select("#legend").html("").attr("class", "").attr("style", "");
  chart.config = rick();
  chart.graph = chart.config.graph;
  chart.update = function(x, y) {
    if (x && y) {
      resize(x, y);
    }
    return rescale();
  };
  resize(599, 299);
  return autoresize();
};

init_ui = function() {
  d3.select("button#startStats").on("click", function() {
    if ((chart != null ? chart.redraw : void 0) != null) {
      chart.redraw(cur_session);
    } else {
      draw_chart();
    }
    return window.graph_started = true;
  });
  d3.select("button#redrawStats").on("click", function() {
    return chart.updateData(cur_session);
  });
  return d3.select("button#drawrick").on("click", function() {
    if (!chart.graph) {
      return start_graph();
    } else {
      return chart.update();
    }
  });
};
