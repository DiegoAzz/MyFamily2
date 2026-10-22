import {
  Scene,
  ArcRotateCamera,
  Vector3,
  Scalar,
} from "@babylonjs/core";
import { GAME_CONSTANTS, PlayerInputPayload } from "@wildborn/shared";
import { Avatar3D } from "./Avatar3D.js";
import { IslandScene } from "./IslandScene.js";

export class PlayerController {
  public camera: ArcRotateCamera;
  public avatar: Avatar3D;
  public islandScene: IslandScene;

  // Estados de entrada
  private keys: Record<string, boolean> = {};
  public isPointerLocked: boolean = false;
  private mouseSensitivity: number = 0.0025;

  // Inputs táctiles para móviles
  public touchForward: number = 0;
  public touchStrafe: number = 0;
  public touchSprint: boolean = false;
  public touchJump: boolean = false;

  // Físicas locales
  public position: Vector3 = new Vector3(0, 2, 0);
  public velocity: Vector3 = new Vector3(0, 0, 0);
  public yaw: number = 0;
  public pitch: number = 0.35; // Ángulo vertical de la cámara
  public isGrounded: boolean = true;
  private currentAnimation: string = "idle";
  private inputSeq: number = 0;

  // Callbacks
  public onSendInput?: (input: PlayerInputPayload) => void;
  public onInteract?: () => void;
  public onBuildCampfire?: () => void;

  constructor(islandScene: IslandScene, avatar: Avatar3D, canvas: HTMLCanvasElement) {
    this.islandScene = islandScene;
    this.avatar = avatar;

    // 1. Cámara en Tercera Persona Orbital
    this.camera = new ArcRotateCamera(
      "thirdPersonCamera",
      -Math.PI / 2, // Alpha
      Math.PI / 3,  // Beta
      4.8,          // Distancia (Radius)
      new Vector3(0, 1.4, 0), // Target
      islandScene.scene
    );
    this.camera.lowerRadiusLimit = 2.0;
    this.camera.upperRadiusLimit = 8.5;
    this.camera.lowerBetaLimit = 0.1;
    this.camera.upperBetaLimit = Math.PI / 2 - 0.05; // No atravesar el suelo
    this.camera.checkCollisions = true;

    // Activar como cámara principal
    this.islandScene.scene.activeCamera = this.camera;

    // Configuración de controles
    this.setupInputs(canvas);
  }

  private setupInputs(canvas: HTMLCanvasElement) {
    // Teclado
    window.addEventListener("keydown", (e) => {
      this.keys[e.code] = true;

      if (e.code === "KeyE") {
        this.onInteract?.();
      } else if (e.code === "KeyB") {
        this.onBuildCampfire?.();
      }
    });

    window.addEventListener("keyup", (e) => {
      this.keys[e.code] = false;
    });

    // Pointer Lock y Mouse Look
    canvas.addEventListener("click", () => {
      if (!this.isPointerLocked) {
        canvas.requestPointerLock();
      }
    });

    document.addEventListener("pointerlockchange", () => {
      this.isPointerLocked = document.pointerLockElement === canvas;
    });

    window.addEventListener("mousemove", (e) => {
      if (this.isPointerLocked) {
        this.rotateCamera(e.movementX, e.movementY);
      }
    });

    // Rotación de Cámara por Toque en Pantalla Móvil (Touch Look)
    let lookTouchId: number | null = null;
    let lastTouchX = 0;
    let lastTouchY = 0;

    canvas.addEventListener(
      "touchstart",
      (e) => {
        for (let i = 0; i < e.changedTouches.length; i++) {
          const touch = e.changedTouches[i];
          // Si el toque es en el área central o derecha de la pantalla y no tenemos dedo de cámara activo
          if (touch.clientX > window.innerWidth * 0.35 && lookTouchId === null) {
            lookTouchId = touch.identifier;
            lastTouchX = touch.clientX;
            lastTouchY = touch.clientY;
            break;
          }
        }
      },
      { passive: true }
    );

    canvas.addEventListener(
      "touchmove",
      (e) => {
        if (lookTouchId === null) return;
        for (let i = 0; i < e.changedTouches.length; i++) {
          const touch = e.changedTouches[i];
          if (touch.identifier === lookTouchId) {
            const dx = touch.clientX - lastTouchX;
            const dy = touch.clientY - lastTouchY;
            lastTouchX = touch.clientX;
            lastTouchY = touch.clientY;
            this.rotateCamera(dx, dy);
            break;
          }
        }
      },
      { passive: true }
    );

    const endLookTouch = (e: TouchEvent) => {
      if (lookTouchId === null) return;
      for (let i = 0; i < e.changedTouches.length; i++) {
        if (e.changedTouches[i].identifier === lookTouchId) {
          lookTouchId = null;
          break;
        }
      }
    };

    canvas.addEventListener("touchend", endLookTouch, { passive: true });
    canvas.addEventListener("touchcancel", endLookTouch, { passive: true });
  }

  public rotateCamera(deltaX: number, deltaY: number) {
    // Rotación horizontal (Yaw)
    this.yaw += deltaX * this.mouseSensitivity;
    // Rotación vertical (Pitch)
    this.camera.beta = Scalar.Clamp(
      this.camera.beta + deltaY * this.mouseSensitivity,
      0.15,
      Math.PI / 2 - 0.05
    );
  }

  public update(dt: number) {
    // 1. Leer inputs (Teclado + Toque móvil)
    let forward = this.touchForward;
    let strafe = this.touchStrafe;

    if (this.keys["KeyW"] || this.keys["ArrowUp"]) forward += 1;
    if (this.keys["KeyS"] || this.keys["ArrowDown"]) forward -= 1;
    if (this.keys["KeyD"] || this.keys["ArrowRight"]) strafe += 1;
    if (this.keys["KeyA"] || this.keys["ArrowLeft"]) strafe -= 1;

    forward = Math.max(-1, Math.min(1, forward));
    strafe = Math.max(-1, Math.min(1, strafe));

    const sprint = Boolean(this.keys["ShiftLeft"] || this.keys["ShiftRight"] || this.touchSprint);
    const jump = Boolean(this.keys["Space"] || this.touchJump);
    if (this.touchJump) {
      this.touchJump = false; // Reset de impulso de salto táctil
    }

    // 2. Simulación local predictiva (Client Prediction)
    const speed = sprint ? GAME_CONSTANTS.PLAYER_SPRINT_SPEED : GAME_CONSTANTS.PLAYER_WALK_SPEED;

    let moveX = 0;
    let moveZ = 0;

    if (forward !== 0 || strafe !== 0) {
      const sinY = Math.sin(this.yaw);
      const cosY = Math.cos(this.yaw);

      const fX = sinY * forward;
      const fZ = cosY * forward;
      const sX = cosY * strafe;
      const sZ = -sinY * strafe;

      const len = Math.hypot(fX + sX, fZ + sZ);
      if (len > 0.001) {
        moveX = ((fX + sX) / len) * speed;
        moveZ = ((fZ + sZ) / len) * speed;
      }
    }

    this.velocity.x = moveX;
    this.velocity.z = moveZ;

    // Salto
    if (jump && this.isGrounded) {
      this.velocity.y = GAME_CONSTANTS.PLAYER_JUMP_FORCE;
      this.isGrounded = false;
      this.currentAnimation = "jump";
    }

    // Gravedad
    if (!this.isGrounded) {
      this.velocity.y -= GAME_CONSTANTS.GRAVITY * dt;
    }

    // Aplicar movimiento
    this.position.x += this.velocity.x * dt;
    this.position.z += this.velocity.z * dt;
    this.position.y += this.velocity.y * dt;

    // Límites de la isla
    const distCenter = Math.hypot(this.position.x, this.position.z);
    if (distCenter > GAME_CONSTANTS.ISLAND_RADIUS) {
      const factor = GAME_CONSTANTS.ISLAND_RADIUS / distCenter;
      this.position.x *= factor;
      this.position.z *= factor;
    }

    // Altura del terreno
    const groundY = this.islandScene.calculateTerrainHeight(this.position.x, this.position.z);
    if (this.position.y <= groundY) {
      this.position.y = groundY;
      this.velocity.y = 0;
      this.isGrounded = true;

      if (moveX !== 0 || moveZ !== 0) {
        this.currentAnimation = sprint ? "sprint" : "walk";
      } else {
        this.currentAnimation = "idle";
      }
    }

    // 3. Actualizar Avatar 3D
    this.avatar.setPositionAndYaw(this.position, this.yaw);
    this.avatar.updateAnimation(this.currentAnimation, dt);

    // 4. Actualizar Cámara Tercera Persona para que siga suavemente al avatar
    this.camera.target.set(this.position.x, this.position.y + 1.35, this.position.z);
    this.camera.alpha = -this.yaw - Math.PI / 2;

    // 5. Enviar intención de input al servidor autoritativo
    this.inputSeq++;
    this.onSendInput?.({
      seq: this.inputSeq,
      forward,
      strafe,
      sprint,
      jump,
      yaw: this.yaw,
      timestamp: Date.now(),
    });
  }

  // Reconciliación con la verdad del servidor
  public reconcile(serverX: number, serverY: number, serverZ: number) {
    const errorDist = Math.hypot(this.position.x - serverX, this.position.z - serverZ);
    // Si la discrepancia con el servidor es mayor a 1.2 metros, corregir suavemente
    if (errorDist > 1.2) {
      this.position.x = Scalar.Lerp(this.position.x, serverX, 0.25);
      this.position.z = Scalar.Lerp(this.position.z, serverZ, 0.25);
    }
  }
}
