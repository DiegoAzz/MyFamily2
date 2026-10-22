import colyseus, { type Client } from "colyseus";
import {
  GAME_CONSTANTS,
  MessageType,
  PlayerInputPayload,
  ChatMessagePayload,
  InteractPayload,
  BuildPayload,
} from "@wildborn/shared";
import { IslandState } from "./schema/IslandState.js";
import { PlayerState } from "./schema/PlayerState.js";
import { ResourceNodeState } from "./schema/ResourceNodeState.js";
import { StructureState } from "./schema/StructureState.js";

export class IslandRoom extends colyseus.Room<IslandState> {
  maxClients = GAME_CONSTANTS.MAX_PLAYERS_PER_ROOM;

  onCreate(options: any) {
    this.setState(new IslandState());
    if (options && options.islandName) {
      this.state.islandName = options.islandName;
    }

    // Inicializar nodos de recursos en la isla
    this.spawnInitialResources();

    // Mensajes de entrada del jugador (Movimiento e intenciones)
    this.onMessage(MessageType.INPUT, (client, data: PlayerInputPayload) => {
      this.handlePlayerInput(client, data);
    });

    // Mensajes de interacción / recolección
    this.onMessage(MessageType.INTERACT, (client, data: InteractPayload) => {
      this.handlePlayerInteract(client, data);
    });

    // Mensajes de construcción
    this.onMessage(MessageType.BUILD, (client, data: BuildPayload) => {
      this.handlePlayerBuild(client, data);
    });

    // Mensajes de chat
    this.onMessage(MessageType.CHAT, (client, text: string) => {
      this.handlePlayerChat(client, text);
    });

    // Mensajes de latencia (ping / pong)
    this.onMessage(MessageType.PING, (client, data: { timestamp: number }) => {
      client.send(MessageType.PONG, { timestamp: data?.timestamp || Date.now() });
    });

    // Loop de simulación autoritativo a 20 Hz (50ms por tick)
    this.setSimulationInterval(
      (deltaTime) => this.updateSimulation(deltaTime / 1000),
      1000 / GAME_CONSTANTS.SERVER_TICK_RATE
    );

    console.log(`[IslandRoom] Sala creada: ${this.roomId} - ${this.state.islandName}`);
  }

  onJoin(client: Client, options: any) {
    const player = new PlayerState();
    player.id = client.sessionId;
    player.name = (options && options.name) ? String(options.name).slice(0, 16) : `Nómada_${client.sessionId.slice(0, 4)}`;

    // Spawn en la costa de la isla (anillo entre radio 25 y 45)
    const angle = Math.random() * Math.PI * 2;
    const spawnDist = 30 + Math.random() * 15;
    player.x = Math.cos(angle) * spawnDist;
    player.z = Math.sin(angle) * spawnDist;
    player.y = this.getTerrainHeight(player.x, player.z);
    player.yaw = angle + Math.PI; // Mirando hacia el centro de la isla

    this.state.players.set(client.sessionId, player);

    console.log(`[IslandRoom] Jugador unido: ${player.name} (${client.sessionId}) en (${player.x.toFixed(1)}, ${player.z.toFixed(1)})`);

    // Notificar en el chat del servidor
    this.broadcast(MessageType.CHAT, {
      senderId: "system",
      senderName: "Sistema",
      text: `¡${player.name} ha despertado en la orilla de la isla!`,
      timestamp: Date.now(),
    } as ChatMessagePayload);
  }

  async onLeave(client: Client, consented: boolean) {
    const player = this.state.players.get(client.sessionId);
    const playerName = player ? player.name : client.sessionId;

    console.log(`[IslandRoom] Jugador saliendo: ${playerName} (consented: ${consented})`);

    try {
      if (!consented) {
        // Reconexión con tiempo de gracia (15 segundos)
        await this.allowReconnection(client, GAME_CONSTANTS.RECONNECT_TIMEOUT_SEC);
        console.log(`[IslandRoom] ¡Jugador ${playerName} reconectado exitosamente!`);
        return;
      }
    } catch (e) {
      console.log(`[IslandRoom] Tiempo de reconexión expirado para ${playerName}`);
    }

    this.state.players.delete(client.sessionId);
    this.broadcast(MessageType.CHAT, {
      senderId: "system",
      senderName: "Sistema",
      text: `${playerName} abandonó la isla.`,
      timestamp: Date.now(),
    } as ChatMessagePayload);
  }

  private handlePlayerInput(client: Client, data: PlayerInputPayload) {
    const player = this.state.players.get(client.sessionId);
    if (!player || player.isDead) return;

    // Sanitizar inputs
    const forward = Math.max(-1, Math.min(1, data.forward || 0));
    const strafe = Math.max(-1, Math.min(1, data.strafe || 0));
    const sprint = Boolean(data.sprint);
    const jump = Boolean(data.jump);
    const yaw = Number(data.yaw) || 0;

    player.yaw = yaw;
    player.lastSeq = data.seq || player.lastSeq + 1;

    // Calcular velocidad deseada según inputs
    const speed = sprint ? GAME_CONSTANTS.PLAYER_SPRINT_SPEED : GAME_CONSTANTS.PLAYER_WALK_SPEED;

    let moveX = 0;
    let moveZ = 0;

    if (forward !== 0 || strafe !== 0) {
      // Vector de movimiento relativo a la orientación (yaw)
      const sinY = Math.sin(yaw);
      const cosY = Math.cos(yaw);

      // Adelante / Atrás
      const fX = sinY * forward;
      const fZ = cosY * forward;

      // Derecha / Izquierda (perpendicular)
      const sX = cosY * strafe;
      const sZ = -sinY * strafe;

      let len = Math.hypot(fX + sX, fZ + sZ);
      if (len > 0.001) {
        moveX = ((fX + sX) / len) * speed;
        moveZ = ((fZ + sZ) / len) * speed;
      }
    }

    player.vx = moveX;
    player.vz = moveZ;

    // Salto
    if (jump && player.isGrounded) {
      player.vy = GAME_CONSTANTS.PLAYER_JUMP_FORCE;
      player.isGrounded = false;
      player.animation = "jump";
    } else if (!player.isGrounded) {
      player.animation = "jump";
    } else if (moveX !== 0 || moveZ !== 0) {
      player.animation = sprint ? "sprint" : "walk";
    } else {
      player.animation = "idle";
    }
  }

  private handlePlayerInteract(client: Client, data: InteractPayload) {
    const player = this.state.players.get(client.sessionId);
    if (!player || player.isDead) return;

    if (data.targetType === "resource") {
      const node = this.state.resources.get(data.targetId);
      if (!node || !node.available) return;

      // Validación estricta de distancia en servidor (máximo 4 metros)
      const dist = Math.hypot(player.x - node.x, player.z - node.z);
      if (dist > 4.0) {
        return; // Fuera de rango
      }

      // Aplicar daño al nodo de recurso
      node.health -= 25;
      if (node.health <= 0) {
        node.available = false;
        node.respawnAt = Date.now() + 45000; // Respawn en 45 segundos

        // Notificar recolección
        const resourceName = node.type === "tree" ? "Madera (+5)" : node.type === "rock" ? "Piedra (+4)" : "Bayas (+3)";
        client.send("harvest_success", {
          resourceType: node.type,
          amount: node.type === "tree" ? 5 : node.type === "rock" ? 4 : 3,
          message: `¡Recolectaste ${resourceName}!`,
        });
      }
    }
  }

  private handlePlayerBuild(client: Client, data: BuildPayload) {
    const player = this.state.players.get(client.sessionId);
    if (!player || player.isDead) return;

    // Validación de distancia (máximo 6 metros del jugador)
    const dist = Math.hypot(player.x - data.x, player.z - data.z);
    if (dist > 6.0) return;

    const structureId = `struct_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const structure = new StructureState();
    structure.id = structureId;
    structure.type = data.structureType || "campfire";
    structure.ownerId = client.sessionId;
    structure.x = data.x;
    structure.z = data.z;
    structure.y = this.getTerrainHeight(data.x, data.z);
    structure.rotY = data.rotY || 0;

    this.state.structures.set(structureId, structure);

    this.broadcast(MessageType.CHAT, {
      senderId: "system",
      senderName: "Sistema",
      text: `${player.name} construyó una ${structure.type === "campfire" ? "Fogata" : "Estructura"} en el campamento.`,
      timestamp: Date.now(),
    } as ChatMessagePayload);
  }

  private handlePlayerChat(client: Client, text: string) {
    const player = this.state.players.get(client.sessionId);
    if (!player) return;

    const cleaned = String(text || "").trim().slice(0, 100);
    if (cleaned.length === 0) return;

    this.broadcast(MessageType.CHAT, {
      senderId: client.sessionId,
      senderName: player.name,
      text: cleaned,
      timestamp: Date.now(),
    } as ChatMessagePayload);
  }

  private updateSimulation(dt: number) {
    const now = Date.now();
    this.state.serverTime = now;

    // Ciclo día/noche (10 minutos por día completo)
    this.state.timeOfDay = ((now / 1000) % GAME_CONSTANTS.DAY_DURATION_SEC) / GAME_CONSTANTS.DAY_DURATION_SEC;

    // Actualizar movimiento físico y supervivencia de cada jugador
    this.state.players.forEach((player, sessionId) => {
      if (player.isDead) return;

      // 1. Integración de posición en X y Z
      player.x += player.vx * dt;
      player.z += player.vz * dt;

      // 2. Límites circulares de la isla (no caer al infinito)
      const distFromCenter = Math.hypot(player.x, player.z);
      if (distFromCenter > GAME_CONSTANTS.ISLAND_RADIUS) {
        const factor = GAME_CONSTANTS.ISLAND_RADIUS / distFromCenter;
        player.x *= factor;
        player.z *= factor;
        player.vx = 0;
        player.vz = 0;
      }

      // 3. Físicas verticales y terreno
      const groundY = this.getTerrainHeight(player.x, player.z);

      if (!player.isGrounded) {
        player.vy -= GAME_CONSTANTS.GRAVITY * dt;
        player.y += player.vy * dt;

        if (player.y <= groundY) {
          player.y = groundY;
          player.vy = 0;
          player.isGrounded = true;
          if (player.vx !== 0 || player.vz !== 0) {
            player.animation = "walk";
          } else {
            player.animation = "idle";
          }
        }
      } else {
        // Seguir suavemente la altura del terreno
        player.y = groundY;
      }

      // 4. Supervivencia: Hambre y Sed decaen
      player.hunger = Math.max(0, player.hunger - GAME_CONSTANTS.HUNGER_DECAY_RATE * dt);
      player.thirst = Math.max(0, player.thirst - GAME_CONSTANTS.THIRST_DECAY_RATE * dt);

      // Si hambre o sed llegan a 0, recibir daño de inanición
      if (player.hunger <= 0 || player.thirst <= 0) {
        player.health = Math.max(0, player.health - GAME_CONSTANTS.STARVATION_DAMAGE_RATE * dt);
        if (player.health <= 0) {
          player.isDead = true;
          player.animation = "death";
          this.broadcast(MessageType.CHAT, {
            senderId: "system",
            senderName: "Sistema",
            text: `¡${player.name} sucumbió a las inclemencias de la isla!`,
            timestamp: Date.now(),
          } as ChatMessagePayload);
        }
      }
    });

    // Respawn de recursos
    this.state.resources.forEach((node) => {
      if (!node.available && now >= node.respawnAt) {
        node.available = true;
        node.health = node.maxHealth;
      }
    });
  }

  // Función matemática determinista de la altura del terreno de la isla
  private getTerrainHeight(x: number, z: number): number {
    const dist = Math.hypot(x, z);
    if (dist >= GAME_CONSTANTS.ISLAND_RADIUS) {
      return -2.0; // En el agua
    }
    // Colina central con radio de 80 metros y altura de hasta 12 metros
    const islandProfile = Math.cos((dist / GAME_CONSTANTS.ISLAND_RADIUS) * (Math.PI / 2));
    const hillHeight = Math.pow(islandProfile, 1.8) * 10.0;
    // Pequeñas ondulaciones orgánicas
    const bumps = Math.sin(x * 0.08) * Math.cos(z * 0.08) * 1.2;
    return Math.max(0.1, hillHeight + bumps);
  }

  private spawnInitialResources() {
    let idCounter = 1;

    // 1. Árboles (50)
    for (let i = 0; i < 50; i++) {
      const angle = (i / 50) * Math.PI * 2 + (Math.sin(i * 13) * 0.3);
      const dist = 15 + (Math.abs(Math.sin(i * 7)) * 75);
      const x = Math.cos(angle) * dist;
      const z = Math.sin(angle) * dist;
      const y = this.getTerrainHeight(x, z);

      const node = new ResourceNodeState();
      node.id = `tree_${idCounter++}`;
      node.type = "tree";
      node.x = x;
      node.y = y;
      node.z = z;
      node.health = 100;
      node.maxHealth = 100;
      node.available = true;
      this.state.resources.set(node.id, node);
    }

    // 2. Rocas de cantera (30)
    for (let i = 0; i < 30; i++) {
      const angle = (i / 30) * Math.PI * 2 + 0.5;
      const dist = 35 + (Math.abs(Math.cos(i * 5)) * 60);
      const x = Math.cos(angle) * dist;
      const z = Math.sin(angle) * dist;
      const y = this.getTerrainHeight(x, z);

      const node = new ResourceNodeState();
      node.id = `rock_${idCounter++}`;
      node.type = "rock";
      node.x = x;
      node.y = y;
      node.z = z;
      node.health = 120;
      node.maxHealth = 120;
      node.available = true;
      this.state.resources.set(node.id, node);
    }

    // 3. Arbustos de bayas (20)
    for (let i = 0; i < 20; i++) {
      const angle = (i / 20) * Math.PI * 2 + 1.2;
      const dist = 10 + (Math.abs(Math.sin(i * 9)) * 50);
      const x = Math.cos(angle) * dist;
      const z = Math.sin(angle) * dist;
      const y = this.getTerrainHeight(x, z);

      const node = new ResourceNodeState();
      node.id = `bush_${idCounter++}`;
      node.type = "bush";
      node.x = x;
      node.y = y;
      node.z = z;
      node.health = 50;
      node.maxHealth = 50;
      node.available = true;
      this.state.resources.set(node.id, node);
    }
  }
}
