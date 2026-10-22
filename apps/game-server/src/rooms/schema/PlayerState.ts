import { Schema, type } from "@colyseus/schema";
import { GAME_CONSTANTS } from "@wildborn/shared";

export class PlayerState extends Schema {
  @type("string") id: string = "";
  @type("string") name: string = "Explorador";

  // Posición y Velocidad Autoritativa en 3D
  @type("number") x: number = 0;
  @type("number") y: number = 1.0;
  @type("number") z: number = 0;
  @type("number") vx: number = 0;
  @type("number") vy: number = 0;
  @type("number") vz: number = 0;
  @type("number") yaw: number = 0; // Rotación horizontal

  // Estado visual / animación
  @type("string") animation: string = "idle"; // "idle" | "walk" | "sprint" | "jump"
  @type("boolean") isGrounded: boolean = true;

  // Supervivencia
  @type("number") health: number = GAME_CONSTANTS.MAX_HEALTH;
  @type("number") hunger: number = GAME_CONSTANTS.MAX_HUNGER;
  @type("number") thirst: number = GAME_CONSTANTS.MAX_THIRST;
  @type("boolean") isDead: boolean = false;

  // Sincronización de inputs
  @type("number") lastSeq: number = 0;
  @type("number") lastInputTimestamp: number = 0;
}
