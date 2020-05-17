using Julog, PDDL, Gen
using InverseTAMP

include("model.jl")
include("render.jl")

path = joinpath(dirname(pathof(InverseTAMP)), "..", "domains", "gridworld")

domain = load_domain(joinpath(path, "domain.pddl"))
problem = load_problem(joinpath(path, "problem-3.pddl"))

# Initialize state, set goal position
state = initialize(problem)
start_pos = (state[:xpos], state[:ypos])
goal_pos = (7, 8)
goal_terms = @julog[xpos == $(goal_pos[1]), ypos == $(goal_pos[2])]

# Check that heuristic search correctly solves the problem
plan, _ = heuristic_search(goal_terms, state, domain; heuristic=manhattan)
println("== Plan ==")
display(plan)
render(state; start=start_pos, goals=goal_pos, plan=plan)
end_state = execute(plan, state, domain)
@test satisfy(goal_terms, end_state, domain)[1] == true

# Visualize full horizon sample-based search
plt = render(state; start=start_pos, goals=goal_pos)
@gif for i=1:20
    plan, _ = sample_search(goal_terms, state, domain, 0.1)
    plt = render!(plan, start_pos; alpha=0.05)
end
display(plt)

# Visualize sample-based replanning search
plt = render(state; start=start_pos, goals=goal_pos)
@gif for i=1:20
    plan, _ = replan_search(goal_terms, state, domain, 0.1, 0.95)
    plt = render!(plan, start_pos; alpha=0.05)
end
display(plt)

# Specify possible goals
goal_set = [(1, 8), (8, 8), (8, 1)]
goal_terms = [@julog([xpos == $(g[1]), ypos == $(g[2])]) for g in goal_set]
goal_colors = [:orange, :magenta, :blue]

# Sample a trajectory as the ground truth (no observation noise)
traj = model(goal_terms, state, domain, Dict(:obs_args => (0.0, 0.0)))
traj = traj[1:length(traj)÷2] # Observe only first half of the trajectory
plt = render(state; start=start_pos, goals=goal_set, goal_colors=goal_colors)
plt = render!(traj, plt; alpha=0.5)

# Construct choicemap from observed partial trajectory
observations = choicemap()
for (i, state) in enumerate(traj)
    i_choices = obs_choicemap(state, Term[], @julog([xpos, ypos]))
    set_submap!(observations, :traj => i, i_choices)
end

# Run importance sampling to infer the likely goal
traces, weights, _ =
    importance_sampling(model, (goal_terms, state, domain), observations, 20)

# Plot sampled trajectory for each trace
plt = render(state; start=start_pos, goals=goal_set, goal_colors=goal_colors)
for (tr, w) in zip(traces, weights)
    traj_smp = get_retval(tr)
    color = goal_colors[tr[:goal]]
    render!(traj_smp[length(traj)+1:end]; alpha=0.5*exp(w), color=color)
end
plt = render!(traj, plt; alpha=0.5) # Plot original trajectory on top

# Compute posterior probability of each goal
goal_probs = zeros(3)
for (tr, w) in zip(traces, weights)
    goal_probs[tr[:goal]] += exp(w)
end
println("Posterior probabilities:")
for (goal, prob) in zip(goal_set, goal_probs)
    @printf "Goal: %s\t Prob: %0.3f\n" goal prob
end