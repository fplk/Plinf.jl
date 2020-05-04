using InverseTAMP
using ShapesWorld
using PyPlot

function pddl_to_scene_graph(state::State)
    g = ShapesWorld.SceneGraph()
    facts = state.facts
    fluents = state.fluents
    objects = []
    # Get the names of all the block objects
    for term in facts
        if term.name == :block
            push!(objects, (term.args[1].name,))
        end
    end

    sizes = fluents[:size]
    xs, ys, zs = fluents[:posx], fluents[:posy], fluents[:posz]
    yaws, pitches, rolls = fluents[:yaw], fluents[:pitch], fluents[:roll]
    for (i, object) in enumerate(objects)
        size = sizes[object]
        ShapesWorld.addObject!(g, Symbol("block", i), ShapesWorld.Box(size, size, size))
        if fluents[:roll][object] != -1
            ShapesWorld.setPose!(g, Symbol("block", i), [xs[object], ys[object], zs[object]],
                        (yaw=yaws[object], pitch=pitches[object], roll=rolls[object]))
        end
    end

    for fact in facts
        if fact.name == :on
            base, top = fact.args
            base, top = (base.name,), (top.name,)
            # Works since each object in objects is unique
            base_idx = findfirst(x -> x == base, objects)
            top_idx = findfirst(x -> x == top, objects)
            x = xs[top]
            y = ys[top]
            theta = yaws[top]
            ShapesWorld.setContact!(g, Symbol("block", base_idx), :top, (),
                        Symbol("block", top_idx), :bottom, (),
                        x, y, theta)
        end
    end

    ShapesWorld.set_prop!(g, :blurWidth, 5)
    ShapesWorld.set_prop!(g, :decayFactor, 0.1)
    return g
end

function scene_graph_to_pddl(scene_graph)

end

function visualize(scene_graph, outdir, frame_name_prefix)
    (rgba, depth, seg, _, _) = ShapesWorld.renderScene(scene_graph)
    png_file_path = joinpath(outdir, frame_name_prefix * ".png")
    PyPlot.imsave(png_file_path, rgba)
end

"""
Currently assumes no rotations.
"""
# TODO: Add in rotation transition
function smooth_transition(initial_sg, final_sg, velocity)
    intermediate_sgs = []

    objects =
    moving_objects = []
    for object in objects
        initial_abs_pos =
        final_abs_pos =
        pos_diff = final_abs_pos - initial_abs_pos

        if pos_diff != zeros(3)
            push!(moving_objects, object)
        end
    end

    prev_sg = initial_sg
    new_sg = copy(prev_sg)
    while prev_sg != final_sg
        # TODO: Make more efficient by not checking objects that already
        # stopped moving
        for object in moving_objects
            prev_pos =
            final_pos =
            if prev_pos != final_pos
                tentative_new_pos = prev_pos + (fill(velocity, 3) .* direction)
                # Handle possible overshooting

            end
        end
        push!(intermediate_sgs, new_sg)
        prev_sg = new_sg
        new_sg = copy(prev_sg)
    end
    return intermediate_sgs
end