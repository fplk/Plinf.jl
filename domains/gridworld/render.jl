using Julog, PDDL, Plots

## Utility functions ##

"Convert gridworld PDDL state to array for plotting."
function state_to_array(state::State)
    width, height = state[:width], state[:height]
    array = zeros(Int64, (width, height))
    for x=1:width, y=1:height
        if state[:(wall($x, $y))] array[y, x] = 1 end
    end
    return array, (width, height)
end

"Convert PDDL plan to trajectory in a gridworld."
function plan_to_traj(plan::Vector{Term}, start::Tuple{Int,Int})
    traj = [collect(start)]
    dirs = Dict(:up => [0, 1], :down => [0, -1],
                :left => [-1, 0], :right => [1, 0])
    for act in plan
        next = traj[end] + get(dirs, act.name, [0, 0])
        push!(traj, next)
    end
    return traj
end

"Make a circle as a Plots.jl shape."
function make_circle(x::Number, y::Number, r::Number)
    pts = Plots.partialcircle(0, 2*pi, 100, r)
    xs, ys = Plots.unzip(pts)
    xs, ys = xs .+ x, ys .+ y
    return Shape(xs, ys)
end

## Gridworld rendering functions ##

"Render gridworld state, optionally with start, goal, and the trace of a plan."
function render!(state::State, plt::Union{Plots.Plot,Nothing}=nothing;
                 show_pos=false, start=nothing, goals=nothing, plan=nothing,
                 goal_colors=nothing, kwargs...)
    # Get last plot if not provided
    plt = (plt == nothing) ? plot!() : plt
    # Plot base grid
    array, (w, h) = state_to_array(state)
    plot!(plt, xticks=(collect(0:size(array)[1]+1) .- 0.5, []),
               yticks=(collect(0:size(array)[2]+1) .- 0.5, []))
    xgrid!(plt, :on, :black, 2, :dashdot, 0.75)
    ygrid!(plt, :on, :black, 2, :dashdot, 0.75)
    cmap = cgrad([RGBA(1,1,1,0), RGBA(0,0,0,1)])
    heatmap!(plt, array, aspect_ratio=1, color=cmap, colorbar_entry=false)
    # Plot start and goal positions
    if isa(start, Tuple{Int,Int})
        annotate!(start[1], start[2], Plots.text("start", 16, :red, :center))
    end
    if goals != nothing
        if isa(goals, Tuple{Int,Int}) goals = [goals] end
        if goal_colors == nothing goal_colors = cgrad(:plasma)[1:3:30] end
        for (g, col) in zip(goals, goal_colors)
            annotate!(g[1], g[2], Plots.text("goal", 16, col, :center))
        end
    end
    # Plot trace of plan
    if (plan != nothing && start != nothing) render!(plan, start, plt) end
    # Plot current position
    if show_pos render_pos!(state, plt) end
    # Resize limits
    xlims!(plt, 0.5, size(array)[1]+0.5)
    ylims!(plt, 0.5, size(array)[2]+0.5)
    return plt
end

function render(state::State; kwargs...)
    # Create new plot and render to it
    return render!(state, plot(size=(600,600), framestyle=:box); kwargs...)
end

function render!(plan::Vector{Term}, start::Tuple{Int,Int},
                 plt::Union{Plots.Plot,Nothing}=nothing;
                 alpha::Float64=0.50, color=:red, radius=0.1)
     # Get last plot if not provided
     plt = (plt == nothing) ? plot!() : plt
     traj = plan_to_traj(plan, start)
     for (x, y) in traj
         dot = make_circle(x, y, radius)
         plot!(plt, dot, color=color, linealpha=0, alpha=alpha, legend=false)
     end
     return plt
end

function render!(traj::Vector{State}, plt::Union{Plots.Plot,Nothing}=nothing;
                 alpha::Float64=0.50, color=:red, radius=0.1)
     # Get last plot if not provided
     plt = (plt == nothing) ? plot!() : plt
     for state in traj
         x, y = state[:xpos], state[:ypos]
         dot = make_circle(x, y, radius)
         plot!(plt, dot, color=color, linealpha=0, alpha=alpha, legend=false)
     end
     return plt
end

"Render position of agent."
function render_pos!(state::State, plt::Union{Plots.Plot,Nothing}=nothing;
                     radius=0.25, color=:black, kwargs...)
    plt = (plt == nothing) ? plot!() : plt
    x, y = state[:xpos], state[:ypos]
    circ = make_circle(x, y, radius)
    plot!(plt, circ, color=color, alpha=1, legend=false)
end

"Render trajectories for each (weighted) trace"
function render_traces!(traces, weights=nothing, plt=nothing;
                        goal_colors=cgrad(:plasma)[1:3:30], max_alpha=0.75,
                        kwargs...)
    weights = weights == nothing ? lognorm(get_score.(traces)) : weights
    for (tr, w) in zip(traces, weights)
        traj = get_retval(tr)
        color = goal_colors[tr[:goal]]
        render!(traj; alpha=max_alpha*exp(w), color=color, radius=0.175)
    end
end

## Diagnostic and statistic plotters ##

"Make default plot canvas with appropriate size and margin."
plot_canvas() = plot(size=(600,600), framestyle=:box, margin=4*Plots.mm)

"""Plot goal probabilities at a particular timestep as a bar chart.
`goal_probs` should be a dictionary or array of goal probabilities."""
function plot_goal_bars!(goal_probs, goal_names=nothing,
                         goal_colors=cgrad(:plasma)[1:3:30]; plt=nothing)
    # Construct new plot if not provided
    if (plt == nothing) plt = plot_canvas() end
    # Extract goal names and probabilities
    if isa(goal_probs, AbstractDict)
        goal_probs = sort(goal_probs)
        if goal_names == nothing goal_names = collect(keys(goal_probs)) end
        goal_probs = collect(values(goal_probs))
    elseif goal_names == nothing
        goal_names = collect(1:length(goal_probs))
    end
    goal_colors = goal_colors[1:length(goal_probs)]
    # Plot bar chart
    plt = bar!(plt, goal_names, goal_probs; color=goal_colors, legend=false,
               ylims=(0.0, 1.0), xlabel="Goals", ylabel="Probability",
               guidefontsize=16, tickfontsize=14)
    ylims!(plt, (0.0, 1.0))
    return plt
end

"""Plot goal probabilities over time as a line graph.
`goal_probs` should be a 2D array of goal probabilities over time."""
function plot_goal_lines!(goal_probs, goal_names=nothing,
                          goal_colors=cgrad(:plasma)[1:3:30];
                          timesteps=nothing, plt=nothing)
    # Construct new plot if not provided
    if (plt == nothing) plt = plot_canvas() end
    # Set default goal names and timesteps
    if (goal_names == nothing)
        goal_names = ["Goal $i" for i in 1:size(goal_probs, 1)] end
    if (timesteps == nothing)
        timesteps = collect(1:size(goal_probs, 2)) end
    # Plot line graph, one series per goal
    plt = plot!(plt, timesteps, goal_probs'; linewidth=3,
                legend=:topright, legendtitle="Goals",
                fg_legend=:transparent, bg_legend=:transparent,
                labels=permutedims(goal_names), color=permutedims(goal_colors),
                ylims=(0.0, 1.0), xlabel="Time", ylabel="Probability",
                guidefontsize=16, tickfontsize=14)
    return plt
end

"Plot histogram of particle weights."
function plot_particle_weights!(weights; plt=nothing)
    # Construct new plot if not provided
    if (plt == nothing) plt = plot_canvas() end
    # Plot histogram
    weights = exp.(weights)
    plt = histogram!(plt, weights; normalize=:probability, legend=false,
                     xlabel="Particle Weights", ylabel="Frequency",
                     guidefontsize=16, tickfontsize=14)
end

"Plot histogram of partial plan lengths."
function plot_plan_lengths!(traces, weights; plt=nothing)
    # Construct new plot if not provided
    if (plt == nothing) plt = plot_canvas() end
    # Get plan lengths from traces
    plan_lengths = map(traces) do tr
        traj_ret = tr[:traj]
        if isa(traj_ret[end], Plinf.ReplanState)
            _, rp = Plinf.get_last_plan_step(traj_ret)
            return length(rp.part_plan)
        else
            plan, traj = tr[:plan]
            return length(plan)
        end
    end
    weights = exp.(weights)
    # Plot histogram
    plt = histogram!(plt, plan_lengths, weights=weights;
                     guidefontsize=16, tickfontsize=14, legend=false,
                     xlabel="Plan lengths", ylabel="Frequency")
end

## Particle filter callback functions ##

"Callback function that renders each state."
function render_cb(t::Int, state, traces, weights; canvas=nothing, kwargs...)
    # Render canvas if not provided
    plt = canvas == nothing ? render(state; kwargs...) : deepcopy(canvas)
    # Render agent's current position
    render_pos!(state, plt; kwargs...)
    # Render predicted trajectories
    render_traces!(traces, weights, plt; kwargs...)
    title!(plt, "t = $t")
    return plt
end

"Callback function for plotting goal probability bar chart."
function goal_bars_cb(t::Int, state, traces, weights; kwargs...)
    goal_names = get(kwargs, :goal_names, [])
    goal_colors = get(kwargs, :goal_colors, cgrad(:plasma)[1:3:30])
    goal_idxs = collect(1:length(goal_names))
    goal_probs = sort(get_goal_probs(traces, weights, goal_idxs))
    plt = plot_goal_bars!(goal_probs, goal_names, goal_colors)
    title!(plt, "t = $t")
    return plt
end

"Callback function for plotting goal probability line graph."
function goal_lines_cb(t::Int, state, traces, weights;
                       goal_probs=[], kwargs...)
    goal_names = get(kwargs, :goal_names, [])
    goal_colors = get(kwargs, :goal_colors, cgrad(:plasma)[1:3:30])
    goal_idxs = collect(1:length(goal_names))
    goal_probs_t = sort(get_goal_probs(traces, weights, goal_idxs))
    push!(goal_probs, collect(values(goal_probs_t)))
    plt = plot_goal_lines!(reduce(hcat, goal_probs), goal_names, goal_colors)
    title!(plt, "t = $t")
    return plt
end

"Callback function for plotting particle weights."
particle_weights_cb(t, state, traces, weights; kwargs...) =
    plot_particle_weights!(weights)

"Callback function for plotting plan lengths."
plan_lengths_cb(t, state, traces, weights; kwargs...) =
    plot_plan_lengths!(traces, weights)

"Callback function that combines a number of subplots."
function multiplot_cb(t::Int, state, traces, weights,
                      plotters=[render_cb]; layout=nothing,
                      animation=nothing, show=true, kwargs...)
    subplots = [p(t, state, traces, weights; kwargs...) for p in plotters]
    margin = plotters == [render_cb] ? 2*Plots.mm : 10*Plots.mm
    if layout == nothing
        layout = length(subplots) > 1 ? (length(subplots) ÷ 2, 2) : (1, 1) end
    plt = plot(subplots...; layout=layout, margin=margin,
               size=(layout[2], layout[1]) .* 600)
    if show display(plt) end # Display the plot in the GUI
    if animation != nothing frame(animation) end # Save frame to animation
    return plt
end
