import { Schema, type } from "@colyseus/schema";

export class StructureState extends Schema {
  @type("string") id: string = "";
  @type("string") type: string = "campfire"; // "campfire"
  @type("string") ownerId: string = "";
  @type("number") x: number = 0;
  @type("number") y: number = 0;
  @type("number") z: number = 0;
  @type("number") rotY: number = 0;
  @type("number") health: number = 200;
  @type("number") createdAt: number = Date.now();
}
