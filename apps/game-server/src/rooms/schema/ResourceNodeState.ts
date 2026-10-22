import { Schema, type } from "@colyseus/schema";

export class ResourceNodeState extends Schema {
  @type("string") id: string = "";
  @type("string") type: string = "tree"; // "tree" | "rock" | "bush"
  @type("number") x: number = 0;
  @type("number") y: number = 0;
  @type("number") z: number = 0;
  @type("number") health: number = 100;
  @type("number") maxHealth: number = 100;
  @type("boolean") available: boolean = true;
  @type("number") respawnAt: number = 0; // Timestamp en ms
}
