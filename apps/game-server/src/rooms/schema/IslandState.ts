import { Schema, MapSchema, type } from "@colyseus/schema";
import { PlayerState } from "./PlayerState.js";
import { ResourceNodeState } from "./ResourceNodeState.js";
import { StructureState } from "./StructureState.js";

export class IslandState extends Schema {
  @type({ map: PlayerState }) players = new MapSchema<PlayerState>();
  @type({ map: ResourceNodeState }) resources = new MapSchema<ResourceNodeState>();
  @type({ map: StructureState }) structures = new MapSchema<StructureState>();

  @type("number") timeOfDay: number = 0.25; // 0.0 (medianoche) - 0.25 (amanecer) - 0.5 (mediodía) - 0.75 (atardecer)
  @type("number") serverTime: number = Date.now();
  @type("string") islandName: string = "Isla Esperanza";
}
