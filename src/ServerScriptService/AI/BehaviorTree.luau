--!strict
-- @author Velumix
-- @version 0.0.1
local BehaviorTree = {}

BehaviorTree.Status = table.freeze({
	Success = "Success",
	Failure = "Failure",
	Running = "Running",
})

export type Blackboard = { [string]: any }
export type Node = {
	Tick: (self: Node, blackboard: Blackboard, dt: number) -> string,
}

function BehaviorTree.Condition(predicate: (Blackboard) -> boolean): Node
	return {
		Tick = function(_self, blackboard)
			return if predicate(blackboard) then BehaviorTree.Status.Success else BehaviorTree.Status.Failure
		end,
	}
end

function BehaviorTree.Action(action: (Blackboard, number) -> string?): Node
	return {
		Tick = function(_self, blackboard, dt)
			return action(blackboard, dt) or BehaviorTree.Status.Success
		end,
	}
end

function BehaviorTree.Sequence(children: { Node }): Node
	return {
		Tick = function(_self, blackboard, dt)
			for _, child in children do
				local status = child:Tick(blackboard, dt)
				if status ~= BehaviorTree.Status.Success then
					return status
				end
			end
			return BehaviorTree.Status.Success
		end,
	}
end

function BehaviorTree.Selector(children: { Node }): Node
	return {
		Tick = function(_self, blackboard, dt)
			for _, child in children do
				local status = child:Tick(blackboard, dt)
				if status ~= BehaviorTree.Status.Failure then
					return status
				end
			end
			return BehaviorTree.Status.Failure
		end,
	}
end

return table.freeze(BehaviorTree)
