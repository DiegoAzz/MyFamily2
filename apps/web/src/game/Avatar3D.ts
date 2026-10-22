import {
  Scene,
  Mesh,
  MeshBuilder,
  StandardMaterial,
  Color3,
  DynamicTexture,
  Vector3,
} from "@babylonjs/core";

export class Avatar3D {
  public rootMesh: Mesh;
  public bodyMesh: Mesh;
  public headMesh: Mesh;
  public backpackMesh: Mesh;
  public nametagMesh: Mesh;
  public isLocal: boolean;
  public name: string;

  private walkAnimTime: number = 0;
  private currentAnimation: string = "idle";

  constructor(scene: Scene, name: string, isLocal: boolean = false) {
    this.name = name;
    this.isLocal = isLocal;

    // Nodo raíz
    this.rootMesh = new Mesh(`avatar_${name}_${Math.random()}`, scene);

    // 1. Cuerpo / Túnica del explorador (Cápsula o Cilindro suavizado)
    this.bodyMesh = MeshBuilder.CreateCylinder("avatarBody", {
      height: 1.1,
      diameterTop: 0.55,
      diameterBottom: 0.45,
      tessellation: 8,
    }, scene);
    this.bodyMesh.position.y = 0.85;
    const bodyMat = new StandardMaterial("matAvatarBody", scene);
    // Túnica verde bosque para local, túnica azulada para remotos
    bodyMat.diffuseColor = isLocal ? new Color3(0.2, 0.65, 0.35) : new Color3(0.25, 0.45, 0.85);
    this.bodyMesh.material = bodyMat;
    this.bodyMesh.parent = this.rootMesh;

    // 2. Cabeza
    this.headMesh = MeshBuilder.CreateSphere("avatarHead", {
      diameter: 0.48,
      segments: 8,
    }, scene);
    this.headMesh.position.y = 1.62;
    const headMat = new StandardMaterial("matAvatarHead", scene);
    headMat.diffuseColor = new Color3(0.92, 0.78, 0.65);
    this.headMesh.material = headMat;
    this.headMesh.parent = this.rootMesh;

    // Pelo / Cinta
    const hair = MeshBuilder.CreateBox("avatarHair", {
      width: 0.52,
      height: 0.2,
      depth: 0.52,
    }, scene);
    hair.position.y = 1.76;
    const hairMat = new StandardMaterial("matHair", scene);
    hairMat.diffuseColor = new Color3(0.25, 0.16, 0.1);
    hair.material = hairMat;
    hair.parent = this.rootMesh;

    // 3. Mochila de Supervivencia en la espalda
    this.backpackMesh = MeshBuilder.CreateBox("avatarBackpack", {
      width: 0.4,
      height: 0.55,
      depth: 0.28,
    }, scene);
    this.backpackMesh.position.set(0, 0.95, -0.32);
    const backpackMat = new StandardMaterial("matBackpack", scene);
    backpackMat.diffuseColor = new Color3(0.48, 0.32, 0.18);
    this.backpackMesh.material = backpackMat;
    this.backpackMesh.parent = this.rootMesh;

    // 4. Nametag flotante en 3D
    this.nametagMesh = this.createNametag(scene, name, isLocal);
    this.nametagMesh.position.y = 2.15;
    this.nametagMesh.parent = this.rootMesh;
  }

  private createNametag(scene: Scene, name: string, isLocal: boolean): Mesh {
    const plane = MeshBuilder.CreatePlane("nametagPlane", { width: 1.8, height: 0.45 }, scene);
    plane.billboardMode = Mesh.BILLBOARDMODE_ALL;

    const dynamicTexture = new DynamicTexture("nametagTexture", { width: 256, height: 64 }, scene, false);
    dynamicTexture.hasAlpha = true;

    const ctx = dynamicTexture.getContext() as any;
    ctx.clearRect(0, 0, 256, 64);

    // Fondo pill oscuro translúcido
    ctx.fillStyle = "rgba(10, 15, 25, 0.75)";
    if (ctx.roundRect) {
      ctx.beginPath();
      ctx.roundRect(10, 10, 236, 44, 12);
      ctx.fill();
    } else {
      ctx.fillRect(10, 10, 236, 44);
    }

    // Texto con color distintivo (Dorado para local, Blanco para remotos)
    ctx.fillStyle = isLocal ? "#f6ad55" : "#edf2f7";
    ctx.font = "bold 24px Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(name, 128, 32);

    dynamicTexture.update();

    const mat = new StandardMaterial("matNametag", scene);
    mat.diffuseTexture = dynamicTexture;
    mat.emissiveColor = new Color3(1, 1, 1);
    mat.specularColor = new Color3(0, 0, 0);
    mat.backFaceCulling = false;
    plane.material = mat;

    return plane;
  }

  public updateAnimation(anim: string, dt: number) {
    this.currentAnimation = anim;

    if (anim === "walk" || anim === "sprint") {
      const speedMult = anim === "sprint" ? 14 : 9;
      this.walkAnimTime += dt * speedMult;

      // Balanceo orgánico del cuerpo al caminar / correr
      this.bodyMesh.position.y = 0.85 + Math.abs(Math.sin(this.walkAnimTime)) * 0.08;
      this.bodyMesh.rotation.z = Math.sin(this.walkAnimTime * 0.5) * 0.05;
      this.headMesh.position.y = 1.62 + Math.abs(Math.sin(this.walkAnimTime)) * 0.08;
      this.backpackMesh.position.y = 0.95 + Math.abs(Math.sin(this.walkAnimTime)) * 0.08;
    } else if (anim === "jump") {
      this.bodyMesh.position.y = 0.95;
      this.bodyMesh.rotation.x = -0.15;
    } else {
      // Idle: respiración suave
      this.walkAnimTime += dt * 2.5;
      this.bodyMesh.position.y = 0.85 + Math.sin(this.walkAnimTime) * 0.02;
      this.bodyMesh.rotation.set(0, 0, 0);
      this.headMesh.position.y = 1.62 + Math.sin(this.walkAnimTime) * 0.02;
      this.backpackMesh.position.y = 0.95 + Math.sin(this.walkAnimTime) * 0.02;
    }
  }

  public setPositionAndYaw(pos: Vector3, yaw: number) {
    this.rootMesh.position.copyFrom(pos);
    this.rootMesh.rotation.y = yaw;
  }

  public dispose() {
    this.rootMesh.dispose(false, true);
  }
}
