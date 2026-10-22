import {
  Scene,
  Mesh,
  MeshBuilder,
  StandardMaterial,
  Color3,
  DynamicTexture,
  Vector3,
  TransformNode,
} from "@babylonjs/core";

export class Avatar3D {
  public rootMesh: Mesh;
  public bodyMesh: Mesh;
  public headMesh: Mesh;
  public backpackMesh: Mesh;
  public nametagMesh: Mesh;

  // Huesos / Pivotes de extremidades articuladas
  private leftArmPivot: TransformNode;
  private rightArmPivot: TransformNode;
  private leftLegPivot: TransformNode;
  private rightLegPivot: TransformNode;

  public isLocal: boolean;
  public name: string;

  private animTime: number = 0;
  private currentAnimation: string = "idle";

  constructor(scene: Scene, name: string, isLocal: boolean = false) {
    this.name = name;
    this.isLocal = isLocal;

    // 1. Nodo raíz del avatar
    this.rootMesh = new Mesh(`avatar_${name}_${Math.random()}`, scene);

    // ==========================================
    // MATERIALES ESTILIZADOS
    // ==========================================
    // Piel suave
    const skinMat = new StandardMaterial("matSkin", scene);
    skinMat.diffuseColor = new Color3(0.96, 0.82, 0.72);
    skinMat.specularColor = new Color3(0.05, 0.05, 0.05);

    // Ropa / Túnica (Verde esmeralda para local, Azul zafiro para otros)
    const jacketMat = new StandardMaterial("matJacket", scene);
    jacketMat.diffuseColor = isLocal ? new Color3(0.12, 0.62, 0.36) : new Color3(0.18, 0.45, 0.88);
    jacketMat.specularColor = new Color3(0.08, 0.08, 0.08);

    // Pantalones de explorador (Gris pizarra oscuro)
    const pantsMat = new StandardMaterial("matPants", scene);
    pantsMat.diffuseColor = new Color3(0.2, 0.24, 0.3);
    pantsMat.specularColor = new Color3(0.04, 0.04, 0.04);

    // Botas y cinturón de cuero marrón
    const leatherMat = new StandardMaterial("matLeather", scene);
    leatherMat.diffuseColor = new Color3(0.42, 0.26, 0.16);
    leatherMat.specularColor = new Color3(0.1, 0.1, 0.1);

    // Pelo castaño
    const hairMat = new StandardMaterial("matHair", scene);
    hairMat.diffuseColor = new Color3(0.28, 0.18, 0.12);
    hairMat.specularColor = new Color3(0.06, 0.06, 0.06);

    // Hebilla dorada
    const goldMat = new StandardMaterial("matGold", scene);
    goldMat.diffuseColor = new Color3(0.95, 0.75, 0.15);
    goldMat.specularColor = new Color3(0.8, 0.7, 0.2);

    // ==========================================
    // 2. TORSO / TÚNICA DE EXPLORADOR
    // ==========================================
    this.bodyMesh = MeshBuilder.CreateCylinder(
      "avatarBody",
      {
        height: 0.85,
        diameterTop: 0.52,
        diameterBottom: 0.42,
        tessellation: 10,
      },
      scene
    );
    this.bodyMesh.position.y = 1.05;
    this.bodyMesh.material = jacketMat;
    this.bodyMesh.parent = this.rootMesh;

    // Cuello de la chaqueta
    const collar = MeshBuilder.CreateCylinder(
      "avatarCollar",
      {
        height: 0.15,
        diameter: 0.48,
        tessellation: 10,
      },
      scene
    );
    collar.position.y = 1.48;
    collar.material = jacketMat;
    collar.parent = this.rootMesh;

    // Cinturón de explorador con hebilla dorada
    const belt = MeshBuilder.CreateCylinder(
      "avatarBelt",
      {
        height: 0.14,
        diameter: 0.45,
        tessellation: 10,
      },
      scene
    );
    belt.position.y = 0.78;
    belt.material = leatherMat;
    belt.parent = this.rootMesh;

    const buckle = MeshBuilder.CreateBox(
      "avatarBuckle",
      {
        width: 0.12,
        height: 0.12,
        depth: 0.06,
      },
      scene
    );
    buckle.position.set(0, 0.78, 0.23);
    buckle.material = goldMat;
    buckle.parent = this.rootMesh;

    // Bolsita de supervivencia en la cadera derecha
    const pouch = MeshBuilder.CreateBox(
      "avatarPouch",
      {
        width: 0.14,
        height: 0.16,
        depth: 0.1,
      },
      scene
    );
    pouch.position.set(0.24, 0.74, 0.05);
    pouch.material = leatherMat;
    pouch.parent = this.rootMesh;

    // ==========================================
    // 3. CABEZA CON CARA ESTILIZADA
    // ==========================================
    this.headMesh = MeshBuilder.CreateSphere(
      "avatarHead",
      {
        diameter: 0.52,
        segments: 12,
      },
      scene
    );
    this.headMesh.position.y = 1.76;
    this.headMesh.material = this.createFaceMaterial(scene);
    this.headMesh.parent = this.rootMesh;

    // Pelo con volumen estilizado y flequillo
    const hairBase = MeshBuilder.CreateSphere(
      "avatarHairBase",
      {
        diameter: 0.56,
        segments: 10,
      },
      scene
    );
    hairBase.position.set(0, 1.84, -0.04);
    hairBase.scaling.set(1.0, 0.9, 1.05);
    hairBase.material = hairMat;
    hairBase.parent = this.rootMesh;

    // Mechón frontal / flequillo
    const bangs = MeshBuilder.CreateBox(
      "avatarBangs",
      {
        width: 0.44,
        height: 0.15,
        depth: 0.18,
      },
      scene
    );
    bangs.position.set(0, 1.95, 0.18);
    bangs.rotation.x = 0.35;
    bangs.material = hairMat;
    bangs.parent = this.rootMesh;

    // Cinta de aventurero en la frente
    const headband = MeshBuilder.CreateCylinder(
      "avatarHeadband",
      {
        height: 0.08,
        diameter: 0.54,
        tessellation: 12,
      },
      scene
    );
    headband.position.y = 1.86;
    headband.material = leatherMat;
    headband.parent = this.rootMesh;

    // ==========================================
    // 4. BRAZOS Y MANOS ARTICULADOS
    // ==========================================
    // Brazo Izquierdo
    this.leftArmPivot = new TransformNode("leftArmPivot", scene);
    this.leftArmPivot.position.set(-0.35, 1.38, 0);
    this.leftArmPivot.parent = this.rootMesh;

    const leftSleeve = MeshBuilder.CreateCylinder(
      "leftSleeve",
      { height: 0.45, diameter: 0.18, tessellation: 8 },
      scene
    );
    leftSleeve.position.y = -0.22;
    leftSleeve.material = jacketMat;
    leftSleeve.parent = this.leftArmPivot as any;

    const leftHand = MeshBuilder.CreateSphere(
      "leftHand",
      { diameter: 0.16, segments: 6 },
      scene
    );
    leftHand.position.y = -0.48;
    leftHand.material = skinMat;
    leftHand.parent = this.leftArmPivot as any;

    // Brazo Derecho
    this.rightArmPivot = new TransformNode("rightArmPivot", scene);
    this.rightArmPivot.position.set(0.35, 1.38, 0);
    this.rightArmPivot.parent = this.rootMesh;

    const rightSleeve = MeshBuilder.CreateCylinder(
      "rightSleeve",
      { height: 0.45, diameter: 0.18, tessellation: 8 },
      scene
    );
    rightSleeve.position.y = -0.22;
    rightSleeve.material = jacketMat;
    rightSleeve.parent = this.rightArmPivot as any;

    const rightHand = MeshBuilder.CreateSphere(
      "rightHand",
      { diameter: 0.16, segments: 6 },
      scene
    );
    rightHand.position.y = -0.48;
    rightHand.material = skinMat;
    rightHand.parent = this.rightArmPivot as any;

    // ==========================================
    // 5. PIERNAS Y BOTAS ARTICULADAS
    // ==========================================
    // Pierna Izquierda
    this.leftLegPivot = new TransformNode("leftLegPivot", scene);
    this.leftLegPivot.position.set(-0.16, 0.72, 0);
    this.leftLegPivot.parent = this.rootMesh;

    const leftPants = MeshBuilder.CreateCylinder(
      "leftPants",
      { height: 0.45, diameter: 0.2, tessellation: 8 },
      scene
    );
    leftPants.position.y = -0.22;
    leftPants.material = pantsMat;
    leftPants.parent = this.leftLegPivot as any;

    const leftBoot = MeshBuilder.CreateBox(
      "leftBoot",
      { width: 0.2, height: 0.25, depth: 0.28 },
      scene
    );
    leftBoot.position.set(0, -0.52, 0.04);
    leftBoot.material = leatherMat;
    leftBoot.parent = this.leftLegPivot as any;

    // Pierna Derecha
    this.rightLegPivot = new TransformNode("rightLegPivot", scene);
    this.rightLegPivot.position.set(0.16, 0.72, 0);
    this.rightLegPivot.parent = this.rootMesh;

    const rightPants = MeshBuilder.CreateCylinder(
      "rightPants",
      { height: 0.45, diameter: 0.2, tessellation: 8 },
      scene
    );
    rightPants.position.y = -0.22;
    rightPants.material = pantsMat;
    rightPants.parent = this.rightLegPivot as any;

    const rightBoot = MeshBuilder.CreateBox(
      "rightBoot",
      { width: 0.2, height: 0.25, depth: 0.28 },
      scene
    );
    rightBoot.position.set(0, -0.52, 0.04);
    rightBoot.material = leatherMat;
    rightBoot.parent = this.rightLegPivot as any;

    // ==========================================
    // 6. MOCHILA DE EXPEDICIÓN DETALLADA
    // ==========================================
    this.backpackMesh = MeshBuilder.CreateBox(
      "avatarBackpack",
      {
        width: 0.42,
        height: 0.56,
        depth: 0.28,
      },
      scene
    );
    this.backpackMesh.position.set(0, 1.1, -0.3);
    this.backpackMesh.material = leatherMat;
    this.backpackMesh.parent = this.rootMesh;

    // Saco de dormir enrollado en la parte superior
    const bedroll = MeshBuilder.CreateCylinder(
      "avatarBedroll",
      {
        height: 0.48,
        diameter: 0.18,
        tessellation: 8,
      },
      scene
    );
    bedroll.rotation.z = Math.PI / 2;
    bedroll.position.set(0, 1.45, -0.3);
    const bedrollMat = new StandardMaterial("matBedroll", scene);
    bedrollMat.diffuseColor = new Color3(0.25, 0.5, 0.35);
    bedroll.material = bedrollMat;
    bedroll.parent = this.rootMesh;

    // Cantimplora metálica en el lateral de la mochila
    const canteen = MeshBuilder.CreateCylinder(
      "avatarCanteen",
      {
        height: 0.22,
        diameter: 0.12,
        tessellation: 8,
      },
      scene
    );
    canteen.position.set(-0.25, 1.05, -0.3);
    canteen.material = goldMat;
    canteen.parent = this.rootMesh;

    // ==========================================
    // 7. NAMETAG FLOTANTE EN 3D
    // ==========================================
    this.nametagMesh = this.createNametag(scene, name, isLocal);
    this.nametagMesh.position.y = 2.45;
    this.nametagMesh.parent = this.rootMesh;

    // Para el jugador local no mostramos el nametag sobre la cabeza
    // para no obstaculizar la vista en tercera persona (su nombre ya está en el HUD).
    // Para jugadores remotos en multijugador, sí se muestra para identificarlos.
    if (isLocal) {
      this.nametagMesh.setEnabled(false);
    }
  }

  // Generar textura dinámica de rostro expresivo con ojos de anime/aventurero
  private createFaceMaterial(scene: Scene): StandardMaterial {
    const texture = new DynamicTexture("faceTexture", { width: 256, height: 256 }, scene, false);
    const ctx = texture.getContext() as any;

    // Color de piel base
    ctx.fillStyle = "#f5d0b0";
    ctx.fillRect(0, 0, 256, 256);

    // Ojos estilizados de aventurero (lado frontal de la esfera)
    const drawEye = (x: number, y: number) => {
      // Blanco exterior
      ctx.fillStyle = "#ffffff";
      ctx.beginPath();
      ctx.ellipse(x, y, 16, 24, 0, 0, Math.PI * 2);
      ctx.fill();

      // Iris profundo azul marino / zafiro
      ctx.fillStyle = "#1e3a8a";
      ctx.beginPath();
      ctx.ellipse(x, y + 2, 12, 19, 0, 0, Math.PI * 2);
      ctx.fill();

      // Pupila negra
      ctx.fillStyle = "#09090b";
      ctx.beginPath();
      ctx.ellipse(x, y + 3, 7, 12, 0, 0, Math.PI * 2);
      ctx.fill();

      // Brillo / Destello superior derecho
      ctx.fillStyle = "#ffffff";
      ctx.beginPath();
      ctx.arc(x + 4, y - 4, 4.5, 0, Math.PI * 2);
      ctx.fill();

      // Brillo secundario inferior izquierdo
      ctx.beginPath();
      ctx.arc(x - 3, y + 6, 2.5, 0, Math.PI * 2);
      ctx.fill();

      // Pestaña superior
      ctx.strokeStyle = "#18181b";
      ctx.lineWidth = 3.5;
      ctx.beginPath();
      ctx.arc(x, y - 4, 18, Math.PI * 1.15, Math.PI * 1.85);
      ctx.stroke();

      // Mejilla sonrojada suave
      ctx.fillStyle = "rgba(244, 63, 94, 0.28)";
      ctx.beginPath();
      ctx.ellipse(x, y + 32, 16, 9, 0, 0, Math.PI * 2);
      ctx.fill();
    };

    drawEye(96, 120);
    drawEye(160, 120);

    // Sonrisa amigable
    ctx.strokeStyle = "#881337";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(128, 168, 14, 0.15 * Math.PI, 0.85 * Math.PI);
    ctx.stroke();

    // Pequeña nariz
    ctx.fillStyle = "#e2a984";
    ctx.beginPath();
    ctx.arc(128, 146, 3, 0, Math.PI * 2);
    ctx.fill();

    texture.update();

    const mat = new StandardMaterial("matFace", scene);
    mat.diffuseTexture = texture;
    mat.specularColor = new Color3(0.04, 0.04, 0.04);
    return mat;
  }

  private createNametag(scene: Scene, name: string, isLocal: boolean): Mesh {
    const plane = MeshBuilder.CreatePlane("nametagPlane", { width: 1.3, height: 0.35 }, scene);
    plane.billboardMode = Mesh.BILLBOARDMODE_ALL;

    const dynamicTexture = new DynamicTexture("nametagTexture", { width: 384, height: 96 }, scene, false);
    dynamicTexture.hasAlpha = true;

    const ctx = dynamicTexture.getContext() as any;
    ctx.clearRect(0, 0, 384, 96);

    // Fondo pill oscuro translúcido con borde sutil
    ctx.fillStyle = "rgba(10, 15, 25, 0.82)";
    ctx.strokeStyle = isLocal ? "rgba(245, 158, 11, 0.7)" : "rgba(56, 189, 248, 0.5)";
    ctx.lineWidth = 3;

    if (ctx.roundRect) {
      ctx.beginPath();
      ctx.roundRect(12, 12, 360, 72, 18);
      ctx.fill();
      ctx.stroke();
    } else {
      ctx.fillRect(12, 12, 360, 72);
      ctx.strokeRect(12, 12, 360, 72);
    }

    // Texto con color distintivo (Dorado ámbar para local, Blanco para remotos)
    ctx.fillStyle = isLocal ? "#f59e0b" : "#f8fafc";
    ctx.font = "bold 32px 'Segoe UI', Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(name, 192, 48);

    dynamicTexture.update();

    const mat = new StandardMaterial("matNametag", scene);
    mat.diffuseTexture = dynamicTexture;
    mat.emissiveColor = new Color3(1, 1, 1);
    mat.specularColor = new Color3(0, 0, 0);
    mat.backFaceCulling = false;
    plane.material = mat;

    return plane;
  }

  // Animaciones procedimentales completas para caminar, correr, saltar y respirar
  public updateAnimation(anim: string, dt: number) {
    this.currentAnimation = anim;

    if (anim === "walk" || anim === "sprint") {
      const isSprint = anim === "sprint";
      const speedMult = isSprint ? 15 : 9.5;
      const strideAngle = isSprint ? 0.75 : 0.52;
      const armAngle = isSprint ? 0.85 : 0.58;

      this.animTime += dt * speedMult;

      // Movimiento alterno de piernas
      this.leftLegPivot.rotation.x = Math.sin(this.animTime) * strideAngle;
      this.rightLegPivot.rotation.x = -Math.sin(this.animTime) * strideAngle;

      // Movimiento alterno de brazos (opuesto a piernas)
      this.leftArmPivot.rotation.x = -Math.sin(this.animTime) * armAngle;
      this.rightArmPivot.rotation.x = Math.sin(this.animTime) * armAngle;

      // Rebote y balanceo rítmico del cuerpo
      const bob = Math.abs(Math.sin(this.animTime)) * (isSprint ? 0.1 : 0.06);
      this.bodyMesh.position.y = 1.05 + bob;
      this.headMesh.position.y = 1.76 + bob;

      // Inclinación hacia adelante al correr
      this.rootMesh.rotation.x = isSprint ? 0.22 : 0.08;
      this.bodyMesh.rotation.z = Math.sin(this.animTime * 0.5) * 0.05;
    } else if (anim === "jump") {
      // Pose de salto: piernas encogidas, brazos abiertos para equilibrio
      this.leftLegPivot.rotation.x = -0.45;
      this.rightLegPivot.rotation.x = -0.3;
      this.leftArmPivot.rotation.x = -0.6;
      this.rightArmPivot.rotation.x = -0.6;
      this.leftArmPivot.rotation.z = -0.3;
      this.rightArmPivot.rotation.z = 0.3;

      this.bodyMesh.position.y = 1.1;
      this.rootMesh.rotation.x = -0.15;
    } else {
      // Idle: respiración suave y postura relajada
      this.animTime += dt * 2.2;
      const breathe = Math.sin(this.animTime) * 0.025;

      this.bodyMesh.position.y = 1.05 + breathe;
      this.headMesh.position.y = 1.76 + breathe;
      this.rootMesh.rotation.x = 0;
      this.bodyMesh.rotation.z = 0;

      // Brazos relajados a los costados
      this.leftArmPivot.rotation.x = Math.sin(this.animTime) * 0.05;
      this.leftArmPivot.rotation.z = -0.06;
      this.rightArmPivot.rotation.x = -Math.sin(this.animTime) * 0.05;
      this.rightArmPivot.rotation.z = 0.06;

      this.leftLegPivot.rotation.set(0, 0, 0);
      this.rightLegPivot.rotation.set(0, 0, 0);
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
