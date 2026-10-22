import React, { useEffect, useRef, useState } from "react";
import { IslandScene } from "./game/IslandScene.js";
import { Avatar3D } from "./game/Avatar3D.js";
import { PlayerController } from "./game/PlayerController.js";
import { NetworkClient } from "./game/NetworkClient.js";
import { HUD } from "./components/HUD.js";
import { ChatBox } from "./components/ChatBox.js";
import { MainMenu } from "./components/MainMenu.js";
import { TouchControls } from "./components/TouchControls.js";
import { ChatMessagePayload } from "@wildborn/shared";
import { Vector3 } from "@babylonjs/core";

export const App: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  // Instancias del juego
  const islandSceneRef = useRef<IslandScene | null>(null);
  const controllerRef = useRef<PlayerController | null>(null);
  const networkRef = useRef<NetworkClient | null>(null);

  // Estados de React
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // HUD & Red
  const [islandName, setIslandName] = useState("Isla Esperanza");
  const [playerCount, setPlayerCount] = useState(1);
  const [ping, setPing] = useState(15);
  const [health, setHealth] = useState(100);
  const [hunger, setHunger] = useState(100);
  const [thirst, setThirst] = useState(100);
  const [posX, setPosX] = useState(0);
  const [posZ, setPosZ] = useState(0);
  const [inventory, setInventory] = useState<Record<string, number>>({
    wood: 10,
    stone: 5,
    berries: 3,
  });
  const [notification, setNotification] = useState<string | null>(null);
  const [chatMessages, setChatMessages] = useState<ChatMessagePayload[]>([]);
  const [isTouchDevice, setIsTouchDevice] = useState(false);

  useEffect(() => {
    const checkTouch = () => {
      const hasTouch =
        typeof window !== "undefined" &&
        ("ontouchstart" in window ||
          navigator.maxTouchPoints > 0 ||
          window.innerWidth < 1024);
      setIsTouchDevice(hasTouch);
    };
    checkTouch();
    window.addEventListener("resize", checkTouch);
    return () => window.removeEventListener("resize", checkTouch);
  }, []);

  useEffect(() => {
    if (!canvasRef.current) return;

    // 1. Inicializar la escena 3D de la isla
    const island = new IslandScene(canvasRef.current);
    islandSceneRef.current = island;

    // 2. Inicializar cliente de red
    const net = new NetworkClient(island);
    networkRef.current = net;

    net.onChatReceived = (msg) => {
      setChatMessages((prev) => [...prev.slice(-30), msg]);
    };

    net.onHarvestSuccess = (info) => {
      setInventory((prev) => {
        const current = prev[info.resourceType] || 0;
        return { ...prev, [info.resourceType]: current + info.amount };
      });

      setNotification(info.message);
      setTimeout(() => setNotification(null), 3000);
    };

    net.onStatsUpdate = (h, hu, th) => {
      setHealth(h);
      setHunger(hu);
      setThirst(th);
    };

    net.onPlayersCountChange = (count) => {
      setPlayerCount(count);
    };

    net.onDisconnected = (reason) => {
      setErrorMessage(reason);
      setIsPlaying(false);
      setIsLoading(false);
    };

    return () => {
      net.disconnect();
      island.engine.dispose();
    };
  }, []);

  const handleStartGame = async (playerName: string, roomCode: string) => {
    if (!islandSceneRef.current || !networkRef.current || !canvasRef.current) return;

    setIsLoading(true);
    setErrorMessage(null);

    try {
      const island = islandSceneRef.current;
      const net = networkRef.current;

      // Registrar listener de spawn antes de conectar
      let pendingSpawn: { x: number; y: number; z: number; yaw: number } | null = null;
      net.onLocalPlayerSpawn = (x, y, z, yaw) => {
        if (controllerRef.current) {
          controllerRef.current.position.set(x, y, z);
          controllerRef.current.yaw = yaw;
          controllerRef.current.avatarYaw = yaw;
          controllerRef.current.avatar.setPositionAndYaw(controllerRef.current.position, controllerRef.current.avatarYaw);
          controllerRef.current.camera.target.set(x, y + 1.25, z);
          controllerRef.current.camera.alpha = -yaw - Math.PI / 2;
        } else {
          pendingSpawn = { x, y, z, yaw };
        }
      };

      // 1. Conectar con el servidor autoritativo
      await net.connectToIsland(playerName, roomCode || undefined);

      // 2. Crear avatar 3D del jugador local
      const localAvatar = new Avatar3D(island.scene, playerName, true);
      const controller = new PlayerController(island, localAvatar, canvasRef.current);
      controllerRef.current = controller;
      (window as any).__controller = controller;
      (window as any).__island = island;

      // Ubicar en posición inicial calculada por el servidor
      const spawnPoint = pendingSpawn as { x: number; y: number; z: number; yaw: number } | null;
      if (spawnPoint) {
        controller.position.set(spawnPoint.x, spawnPoint.y, spawnPoint.z);
        controller.yaw = spawnPoint.yaw;
        controller.avatarYaw = spawnPoint.yaw;
      } else {
        const serverPlayer: any = net.room?.state?.players?.get(net.room?.sessionId || "");
        if (serverPlayer) {
          controller.position.set(serverPlayer.x, serverPlayer.y, serverPlayer.z);
          controller.yaw = serverPlayer.yaw;
          controller.avatarYaw = serverPlayer.yaw;
        }
      }
      controller.avatar.setPositionAndYaw(controller.position, controller.avatarYaw);
      controller.camera.target.set(controller.position.x, controller.position.y + 1.25, controller.position.z);
      controller.camera.alpha = -controller.yaw - Math.PI / 2;

      // Conectar envío de inputs
      controller.onSendInput = (input) => {
        net.sendInput(input);
      };

      controller.onInteract = () => {
        // Enviar interacción hacia el recurso más cercano
        let nearestId: string | null = null;
        let minDist = 4.0;

        net.room?.state.resources.forEach((node: any, id: string) => {
          if (node.available) {
            const dist = Math.hypot(controller.position.x - node.x, controller.position.z - node.z);
            if (dist < minDist) {
              minDist = dist;
              nearestId = id;
            }
          }
        });

        if (nearestId) {
          net.sendInteract(nearestId, "resource");
        }
      };

      controller.onBuildCampfire = () => {
        handleBuildCampfire();
      };

      // Loop de actualización cliente
      let lastTime = performance.now();
      island.scene.onBeforeRenderObservable.add(() => {
        const now = performance.now();
        const dt = Math.min((now - lastTime) / 1000, 0.1);
        lastTime = now;

        if (controllerRef.current) {
          controllerRef.current.update(dt);
          setPosX(controllerRef.current.position.x);
          setPosZ(controllerRef.current.position.z);
        }

        if (networkRef.current) {
          networkRef.current.update(dt);
          setPing(networkRef.current.ping);
        }
      });

      setIsPlaying(true);
      setIsLoading(false);
    } catch (err: any) {
      setIsLoading(false);
      setErrorMessage("No se pudo conectar a la isla: " + (err.message || "Servidor no disponible"));
    }
  };

  const handleBuildCampfire = () => {
    if (!controllerRef.current || !networkRef.current) return;
    if ((inventory.wood || 0) < 5 || (inventory.stone || 0) < 3) {
      setNotification("¡Necesitas 5 Madera y 3 Piedra para una fogata!");
      setTimeout(() => setNotification(null), 3000);
      return;
    }

    // Descontar inventario local
    setInventory((prev) => ({
      ...prev,
      wood: (prev.wood || 0) - 5,
      stone: (prev.stone || 0) - 3,
    }));

    // Spawn 2 metros delante del jugador
    const forwardX = Math.sin(controllerRef.current.yaw) * 2.0;
    const forwardZ = Math.cos(controllerRef.current.yaw) * 2.0;
    const buildX = controllerRef.current.position.x + forwardX;
    const buildZ = controllerRef.current.position.z + forwardZ;

    networkRef.current.sendBuild("campfire", buildX, 0, buildZ, controllerRef.current.yaw);
    setNotification("¡Fogata construida con éxito!");
    setTimeout(() => setNotification(null), 3000);
  };

  const handleSendMessage = (text: string) => {
    networkRef.current?.sendChat(text);
  };

  return (
    <div className="w-full h-full relative select-none">
      {/* Canvas 3D de Babylon.js */}
      <canvas id="renderCanvas" ref={canvasRef} className="w-full h-full block" />

      {/* Menú Principal si no está jugando */}
      {!isPlaying && (
        <MainMenu
          onStartGame={handleStartGame}
          isLoading={isLoading}
          errorMessage={errorMessage}
        />
      )}

      {/* HUD de Supervivencia y Chat en Partida */}
      {isPlaying && (
        <>
          <HUD
            islandName={islandName}
            playerCount={playerCount}
            ping={ping}
            health={health}
            hunger={hunger}
            thirst={thirst}
            posX={posX}
            posZ={posZ}
            inventory={inventory}
            onBuildCampfire={handleBuildCampfire}
            notification={notification}
          />
          <ChatBox
            messages={chatMessages}
            onSendMessage={handleSendMessage}
          />
          {isTouchDevice && (
            <TouchControls
              onMove={(forward, strafe) => {
                if (controllerRef.current) {
                  controllerRef.current.touchForward = forward;
                  controllerRef.current.touchStrafe = strafe;
                }
              }}
              onJump={() => {
                if (controllerRef.current) {
                  controllerRef.current.touchJump = true;
                }
              }}
              onSprintToggle={(sprint) => {
                if (controllerRef.current) {
                  controllerRef.current.touchSprint = sprint;
                }
              }}
              onInteract={() => {
                controllerRef.current?.onInteract?.();
              }}
              onBuild={() => {
                handleBuildCampfire();
              }}
            />
          )}
        </>
      )}
    </div>
  );
};
