--!strict
-- @author Velumix
-- @version 0.0.1
export type Definition = {
	Id: string,
	Priority: Enum.AnimationPriority?,
	Looped: boolean?,
	FadeTime: number?,
	Speed: number?,
	Weight: number?,
	Group: string?,
}

export type Config = {
	Definitions: { [string]: Definition },
	DefaultFadeTime: number,
}

local AnimationConfig: Config = {
	DefaultFadeTime = 0.1,
	-- Add animations shared by the whole game here. Tools can still provide an
	-- Animations folder and load it through AnimationController:LoadFolder().
	Definitions = {},
}

return table.freeze(AnimationConfig)
