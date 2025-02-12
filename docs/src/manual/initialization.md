# [Initialization](@id man-init)

Initialization functions are necessary for proper definition of the optimization problem.
The initialization of a node must be fully defined by an object of type [`AbstractInitData`](@ref).
The user that implements a node must implement a function that processes this object.

Additionally, we provide the function [`update_init_data!`](@ref EMRH.update_init_data!) for the currently implemented types such that a new [`AbstractInitData`](@ref) object is generated based on the solution of a receding horizon problem in a previous time window.
This function is automatically used in the main function [`run_model_rh`](@ref), and it can be easily dispatched upon for new nodes (see the page on *[how to create a new node](@ref how_to-create_node)*).
