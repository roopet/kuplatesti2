class BubbleChart
  constructor: (data) ->
    @data = data
    @width = 940
    @height = 600

    @tooltip = CustomTooltip("gates_tooltip", 240)

    # locations the nodes will move towards
    # depending on which view is currently being
    # used
    @center = {x: @width / 2, y: @height / 2}
    @group_centers = {
      "Matkailu": {x: @width / 3, y: @height / 2},
      "Yritys": {x: @width / 2, y: @height / 2},
      "Hyvinvointi": {x: 2 * @width / 3, y: @height / 2}
      "Kaivannais": {x: @width / 3, y: @height / 4}
    }

    # used when setting up force and
    # moving around nodes
    @layout_gravity = -0.01
    @damper = 0.1

    # these will be set in create_nodes and create_vis
    @vis = null
    @nodes = []
    @force = null
    @circles = null

    # nice looking colors - no reason to buck the trend
    @fill_color = d3.scale.ordinal()
      .domain(["low", "medium", "high"])
      .range(["#d84b2a", "#beccae", "#7aa25c"])

    # use the max total_amount in the data as the max in the scale's domain
    max_amount = d3.max(@data, (d) -> parseInt(d.total_amount))
    @radius_scale = d3.scale.pow().exponent(0.5).domain([0, max_amount]).range([2, 85])
    
    this.create_nodes()
    this.create_vis()

  # create node objects from original data
  # that will serve as the data behind each
  # bubble in the vis, then add each node
  # to @nodes to be used later
  create_nodes: () =>
    @data.forEach (d) =>
      node = {
        id: d.id
        radius: @radius_scale(parseInt(d.total_amount))
        value: d.total_amount
        name: d.grant_title
        org: d.organization
        group: d.group
        x: Math.random() * 900
        y: Math.random() * 800
      }
      @nodes.push node

    @nodes.sort (a,b) -> b.value - a.value


  # create svg at #vis and then 
  # create circle representation for each node
  create_vis: () =>
    @vis = d3.select("#vis").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("id", "svg_vis")

    @circles = @vis.selectAll("circle")
      .data(@nodes, (d) -> d.id)

    # used because we need 'this' in the 
    # mouse callbacks
    that = this

    # radius will be set to 0 initially.
    # see transition below
    @circles.enter().append("circle")
      .attr("r", 0)
      .attr("fill", (d) => @fill_color(d.organization))
      .attr("stroke-width", 2)
      .attr("stroke", (d) => d3.rgb(@fill_color(d.organization)).darker())
      .attr("id", (d) -> "bubble_#{d.id}")
      .on("mouseover", (d,i) -> that.show_details(d,i,this))
      .on("mouseout", (d,i) -> that.hide_details(d,i,this))

    # Fancy transition to make bubbles appear, ending with the
    # correct radius
    @circles.transition().duration(2000).attr("r", (d) -> d.radius)


  # Charge function that is called for each node.
  # Charge is proportional to the diameter of the
  # circle (which is stored in the radius attribute
  # of the circle's associated data.
  # This is done to allow for accurate collision 
  # detection with nodes of different sizes.
  # Charge is negative because we want nodes to 
  # repel.
  # Dividing by 8 scales down the charge to be
  # appropriate for the visualization dimensions.
  charge: (d) ->
    -Math.pow(d.radius, 2.0) / 8

  # Starts up the force layout with
  # the default values
  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .size([@width, @height])

  # Sets up force layout to display
  # all nodes in one circle.
  display_organization_all: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_center(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.hide_groups()

  # Moves all circles towards the @center
  # of the visualization
  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha

  # sets the display of bubbles to be separated
  # into each year. Does this by calling move_towards_year
  display_by_group: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_group(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.display_groups()

  # move all circles to their associated @year_centers 
  move_towards_group: (alpha) =>
    (d) =>
      target = @group_centers[d.group]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1

  # Method to display year titles
  display_groups: () =>
    groups_x = {"Matkailu": 160, "Yritys": @width / 2, "Hyvinvointi": @width - 160, "Kaivannais": @width / 4 }
    groups_data = d3.keys(groups_x)
    groups = @vis.selectAll(".groups")
      .data(groups_data)

    groups.enter().append("text")
      .attr("class", "groups")
      .attr("x", (d) => groups_x[d] )
      .attr("y", 40)
      .attr("text-anchor", "middle")
      .text((d) -> d)

  # Method to hide year titiles
  hide_groups: () =>
    groups = @vis.selectAll(".groups").remove()

  show_details: (data, i, element) =>
    d3.select(element).attr("stroke", "black")
    content = "<span class=\"name\">Hanke:</span><span class=\"value\"> #{data.name}</span><br/>"
    content +="<span class=\"name\">EU ja valtion tuki:</span><span class=\"value\"> $#{addCommas(data.value)}</span><br/>"
    content +="<span class=\"name\">Klusteri:</span><span class=\"value\"> #{data.group}</span><br/>"
    content +="<span class=\"name\">Rahoittava viranomainen:</span><span class=\"value\"> #{data.organization}</span>"
    @tooltip.showTooltip(content,d3.event)


  hide_details: (data, i, element) =>
    d3.select(element).attr("stroke", (d) => d3.rgb(@fill_color(d.organization)).darker())
    @tooltip.hideTooltip()


root = exports ? this

$ ->
  chart = null

  render_vis = (csv) ->
    chart = new BubbleChart csv
    chart.start()
    root.display_all()
  root.display_all = () =>
    chart.display_organization_all()
  root.display_group = () =>
    chart.display_by_group()
  root.toggle_view = (view_type) =>
    if view_type == 'group'
      root.display_group()
    else
      root.display_all()

  d3.csv "data/gates_money.csv", render_vis
