import { Client, Room } from "colyseus.js";
import { MessageType, PlayerInputPayload, ChatMessagePayload } from "@wildborn/shared";
import { IslandScene } from "./IslandScene.js";
import { Avatar3D } from "./Avatar3D.js";
import { Vector3, Scalar } from "@babylonjs/core";

export interface RemotePlayerWrapper {
  avatar: Avatar3D;
  targetPos: Vector3;
  targetYaw: number;
  currentAnim: string;
}

export class NetworkClient {
  public client: Client;
  public room: Room | null = null;
  public islandScene: IslandScene;

  public remotePlayers = new Map<string, RemotePlayerWrapper>();
  public ping: number = 0;
  private lastPingSent: number = 0;

  // Callbacks para la UI React
  public onConnected?: (roomId: string, islandName: string) => void;
  public onDisconnected?: (reason: string) => void;
  public onStatsUpdate?: (health: number, hunger: number, thirst: number) => void;
  public onChatReceived?: (chat: ChatMessagePayload) => void;
  public onHarvestSuccess?: (info: { resourceType: string; amount: number; message: string }) => void;
  public onPlayersCountChange?: (count: number) => void;

  constructor(islandScene: IslandScene) {
    this.islandScene = islandScene;

    // Detectar URL del servidor de juego:
    // 1. Variable de entorno VITE_GAME_SERVER_URL si está provista
    // 2. Si estamos en desarrollo local (localhost / 127.0.0.1) -> ws://localhost:2567
    // 3. En producción HTTPS/WSS (Coolify) -> mismo origen wss://dominio (Nginx hace reverse proxy transparente de /matchmake y /island)
    const envUrl = (import.meta as any).env?.VITE_GAME_SERVER_URL;
    let serverUrl: string;

    if (envUrl) {
      serverUrl = envUrl;
    } else if (
      typeof window !== "undefined" &&
      (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1")
    ) {
      serverUrl = "ws://localhost:2567";
    } else if (typeof window !== "undefined") {
      const isHttps = window.location.protocol === "https:";
      const protocol = isHttps ? "wss:" : "ws:";
      const portPart =
        window.location.port && window.location.port !== "80" && window.location.port !== "443"
          ? `:${window.location.port}`
          : "";
      serverUrl = `${protocol}//${window.location.hostname}${portPart}`;
    } else {
      serverUrl = "ws://localhost:2567";
    }

    console.log(`[NetworkClient] Conectando a servidor Colyseus en: ${serverUrl}`);
    this.client = new Client(serverUrl);
  }

  public async connectToIsland(playerName: string, roomId?: string) {
    try {
      console.log(`[NetworkClient] Conectando a Colyseus...`);
      if (roomId) {
        this.room = await this.client.joinById(roomId, { name: playerName });
      } else {
        this.room = await this.client.joinOrCreate("island", { name: playerName });
      }

      console.log(`[NetworkClient] ¡Conectado a la sala! ID: ${this.room.id}`);
      this.onConnected?.(this.room.id, this.room.state?.islandName || "Isla Esperanza");

      this.setupRoomListeners();
    } catch (err: any) {
      console.error(`[NetworkClient] Error al conectar con el servidor:`, err);
      this.onDisconnected?.(err.message || "Error al conectar al servidor de juego");
      throw err;
    }
  }

  private setupRoomListeners() {
    if (!this.room) return;

    // 1. Jugadores remotos
    this.room.state.players.onAdd((player: any, sessionId: string) => {
      // Si no es el jugador local, instanciar avatar 3D para el otro jugador
      if (sessionId !== this.room?.sessionId) {
        console.log(`[NetworkClient] Jugador remoto apareció: ${player.name} (${sessionId})`);
        const remoteAvatar = new Avatar3D(this.islandScene.scene, player.name, false);
        remoteAvatar.setPositionAndYaw(new Vector3(player.x, player.y, player.z), player.yaw);

        this.remotePlayers.set(sessionId, {
          avatar: remoteAvatar,
          targetPos: new Vector3(player.x, player.y, player.z),
          targetYaw: player.yaw,
          currentAnim: player.animation || "idle",
        });

        // Escuchar cambios de posición del jugador remoto
        player.onChange(() => {
          const wrapper = this.remotePlayers.get(sessionId);
          if (wrapper) {
            wrapper.targetPos.set(player.x, player.y, player.z);
            wrapper.targetYaw = player.yaw;
            wrapper.currentAnim = player.animation;
          }
        });
      } else {
        // Jugador local: sincronizar stats de supervivencia
        player.onChange(() => {
          this.onStatsUpdate?.(player.health, player.hunger, player.thirst);
        });
      }

      this.onPlayersCountChange?.(this.room?.state.players.size || 1);
    });

    this.room.state.players.onRemove((_player: any, sessionId: string) => {
      const wrapper = this.remotePlayers.get(sessionId);
      if (wrapper) {
        wrapper.avatar.dispose();
        this.remotePlayers.delete(sessionId);
      }
      this.onPlayersCountChange?.(this.room?.state.players.size || 1);
    });

    // 2. Nodos de recursos (Árboles, rocas, bayas)
    this.room.state.resources.onAdd((node: any, id: string) => {
      this.islandScene.syncResourceNode(id, node.type, node.x, node.y, node.z, node.available);

      node.onChange(() => {
        this.islandScene.syncResourceNode(id, node.type, node.x, node.y, node.z, node.available);
      });
    });

    // 3. Estructuras (Fogatas)
    this.room.state.structures.onAdd((struct: any, id: string) => {
      this.islandScene.syncStructure(id, struct.type, struct.x, struct.y, struct.z, struct.rotY);
    });

    // 4. Mensajes del Servidor
    this.room.onMessage(MessageType.CHAT, (chatData: ChatMessagePayload) => {
      this.onChatReceived?.(chatData);
    });

    this.room.onMessage("harvest_success", (data: any) => {
      this.onHarvestSuccess?.(data);
    });

    this.room.onMessage(MessageType.PONG, () => {
      this.ping = Math.round(Date.now() - this.lastPingSent);
    });

    this.room.onLeave((code) => {
      console.warn(`[NetworkClient] Desconectado de la sala. Código: ${code}`);
      this.onDisconnected?.(`Conexión perdida con el servidor (código ${code})`);
    });
  }

  // Loop de actualización para interpolar jugadores remotos suavemente a 60 FPS
  public update(dt: number) {
    this.remotePlayers.forEach((wrapper) => {
      // LERP (Linear Interpolation) de posición
      wrapper.avatar.rootMesh.position.x = Scalar.Lerp(
        wrapper.avatar.rootMesh.position.x,
        wrapper.targetPos.x,
        0.35
      );
      wrapper.avatar.rootMesh.position.y = Scalar.Lerp(
        wrapper.avatar.rootMesh.position.y,
        wrapper.targetPos.y,
        0.35
      );
      wrapper.avatar.rootMesh.position.z = Scalar.Lerp(
        wrapper.avatar.rootMesh.position.z,
        wrapper.targetPos.z,
        0.35
      );

      // Interpolación de rotación horizontal
      wrapper.avatar.rootMesh.rotation.y = Scalar.Lerp(
        wrapper.avatar.rootMesh.rotation.y,
        wrapper.targetYaw,
        0.35
      );

      // Animar cuerpo
      wrapper.avatar.updateAnimation(wrapper.currentAnim, dt);
    });

    // Ping periódico cada 3 segundos
    if (Date.now() - this.lastPingSent > 3000 && this.room) {
      this.lastPingSent = Date.now();
      this.room.send(MessageType.PING);
    }
  }

  public sendInput(input: PlayerInputPayload) {
    if (this.room) {
      this.room.send(MessageType.INPUT, input);
    }
  }

  public sendInteract(targetId: string, targetType: "resource" | "structure") {
    if (this.room) {
      this.room.send(MessageType.INTERACT, { targetId, targetType });
    }
  }

  public sendBuild(structureType: string, x: number, y: number, z: number, rotY: number) {
    if (this.room) {
      this.room.send(MessageType.BUILD, { structureType, x, y, z, rotY });
    }
  }

  public sendChat(text: string) {
    if (this.room) {
      this.room.send(MessageType.CHAT, text);
    }
  }

  public disconnect() {
    if (this.room) {
      this.room.leave();
      this.room = null;
    }
    this.remotePlayers.forEach((w) => w.avatar.dispose());
    this.remotePlayers.clear();
  }
}
