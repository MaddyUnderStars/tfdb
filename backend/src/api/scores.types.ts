import { Record, Number, Array, String, Static } from "runtypes";

export const ScoresQuery = Record({
	offset: String.optional(),
})

export const Score = Record({
	rating: Number,
	kills: Number,
	deaths: Number,
	name: String,
})

export const ScoresResponse = Record({
	scores: Array(Score)
})