export enum MessageType {
  INPUT = "input",
  STATE_CORRECTION = "state_correction",
  INTERACT = "interact",
  GATHER = "gather",
  CRAFT = "craft",
  BUILD = "build",
  ATTACK = "attack",
  CHAT = "chat",
  PING = "ping",
  PONG = "pong",
}

export interface PlayerInputPayload {
  seq: number;
  forward: number; // -1, 0, 1 (W / S)
  strafe: number;  // -1, 0, 1 (A / D)
  sprint: boolean;
  jump: boolean;
  yaw: number;     // Ángulo de orientación horizontal en radianes
  timestamp: number;
}

export interface StateCorrectionPayload {
  seq: number;
  x: number;
  y: number;
  z: number;
  vx: number;
  vy: number;
  vz: number;
  yaw: number;
}

export interface ChatMessagePayload {
  senderId: string;
  senderName: string;
  text: string;
  channel?: "global" | "island" | "team";
  timestamp: number;
}

export interface InteractPayload {
  targetId: string;
  targetType: "resource" | "structure" | "creature";
}

export interface CraftPayload {
  recipeId: string;
}

export interface BuildPayload {
  structureType: string;
  x: number;
  y: number;
  z: number;
  rotY: number;
}
