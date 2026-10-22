import {
  Engine,
  Scene,
  Vector3,
  Color3,
  Color4,
  HemisphericLight,
  DirectionalLight,
  ShadowGenerator,
  MeshBuilder,
  StandardMaterial,
  VertexData,
  Mesh,
  TransformNode,
  DynamicTexture,
  ArcRotateCamera,
} from "@babylonjs/core";
import { GAME_CONSTANTS } from "@wildborn/shared";

export class IslandScene {
  public engine: Engine;
  public scene: Scene;
  public terrainMesh: Mesh;
  public waterMesh: Mesh;
  public shadowGenerator: ShadowGenerator;
  public sunLight: DirectionalLight;
  public ambientLight: HemisphericLight;

  private resourceMeshes = new Map<string, Mesh>();
  private structureMeshes = new Map<string, Mesh>();

  constructor(canvas: HTMLCanvasElement) {
    this.engine = new Engine(canvas, true, {
      preserveDrawingBuffer: true,
      stencil: true,
      adaptToDeviceRatio: true,
    });

    this.scene = new Scene(this.engine);
    this.scene.clearColor = new Color4(0.45, 0.72, 0.95, 1.0); // Cielo azul suave
    this.scene.fogMode = Scene.FOGMODE_EXP2;
    this.scene.fogColor = new Color3(0.55, 0.75, 0.9);
    this.scene.fogDensity = 0.0035;

    // 1. Iluminación Cinematográfica
    this.ambientLight = new HemisphericLight(
      "ambientLight",
      new Vector3(0, 1, 0),
      this.scene
    );
    this.ambientLight.diffuse = new Color3(0.9, 0.95, 1.0);
    this.ambientLight.groundColor = new Color3(0.25, 0.35, 0.2);
    this.ambientLight.intensity = 0.75;

    this.sunLight = new DirectionalLight(
      "sunLight",
      new Vector3(-0.6, -0.9, -0.4).normalize(),
      this.scene
    );
    this.sunLight.diffuse = new Color3(1.0, 0.95, 0.85);
    this.sunLight.intensity = 1.35;
    this.sunLight.position = new Vector3(80, 120, 80);

    // Sombras dinámicas suaves
    this.shadowGenerator = new ShadowGenerator(1024, this.sunLight);
    this.shadowGenerator.useBlurExponentialShadowMap = true;
    this.shadowGenerator.blurKernel = 16;

    // 2. Crear Terreno de la Isla
    this.terrainMesh = this.createIslandTerrain();
    this.terrainMesh.receiveShadows = true;

    // 3. Crear Océano Animado
    this.waterMesh = this.createOceanWater();

    // 4. Cámara Inicial Panorámica (Cámara del Menú y de espera)
    const initialCamera = new ArcRotateCamera(
      "initialCamera",
      -Math.PI / 3,
      Math.PI / 2.8,
      90,
      new Vector3(0, 8, 0),
      this.scene
    );
    this.scene.activeCamera = initialCamera;

    // Loop de render
    this.engine.runRenderLoop(() => {
      if (this.scene.activeCamera) {
        this.scene.render();
      }
    });

    window.addEventListener("resize", () => {
      this.engine.resize();
    });
  }

  // Generación procedimental de la isla en 3D
  private createIslandTerrain(): Mesh {
    const size = 260; // 260 x 260 metros
    const subdivisions = 120; // 120 x 120 quads
    const terrain = MeshBuilder.CreateGround("islandTerrain", {
      width: size,
      height: size,
      subdivisions: subdivisions,
      updatable: true,
    }, this.scene);

    const positions = terrain.getVerticesData(VertexBuffer.PositionKind)!;
    const colors: number[] = [];

    for (let i = 0; i < positions.length; i += 3) {
      const x = positions[i];
      const z = positions[i + 2];
      const height = this.calculateTerrainHeight(x, z);
      positions[i + 1] = height;

      // Coloración por altura (Biomas de la isla):
      // Arena en la orilla, pasto verde en el interior, roca en la cima
      if (height < 1.4) {
        // Playa de arena cálida
        colors.push(0.92, 0.82, 0.62, 1.0);
      } else if (height < 7.0) {
        // Pradera verde exuberante
        const variation = (Math.sin(x * 0.2) + Math.cos(z * 0.2)) * 0.05;
        colors.push(0.28 + variation, 0.58 + variation, 0.22, 1.0);
      } else {
        // Cima rocosa escarpada
        colors.push(0.48, 0.46, 0.45, 1.0);
      }
    }

    terrain.setVerticesData(VertexBuffer.PositionKind, positions);
    terrain.setVerticesData(VertexBuffer.ColorKind, colors);

    // Recalcular normales para iluminación suave
    const normals: number[] = [];
    VertexData.ComputeNormals(positions, terrain.getIndices()!, normals);
    terrain.setVerticesData(VertexBuffer.NormalKind, normals);

    // Material estilizado
    const mat = new StandardMaterial("matTerrain", this.scene);
    mat.specularColor = new Color3(0.05, 0.05, 0.05);
    terrain.material = mat;

    return terrain;
  }

  public calculateTerrainHeight(x: number, z: number): number {
    const dist = Math.hypot(x, z);
    if (dist >= GAME_CONSTANTS.ISLAND_RADIUS) {
      return -2.5; // Debajo del agua
    }
    const profile = Math.cos((dist / GAME_CONSTANTS.ISLAND_RADIUS) * (Math.PI / 2));
    const hill = Math.pow(profile, 1.8) * 10.0;
    const bumps = Math.sin(x * 0.08) * Math.cos(z * 0.08) * 1.2;
    return Math.max(0.1, hill + bumps);
  }

  private createOceanWater(): Mesh {
    const water = MeshBuilder.CreateGround("oceanWater", {
      width: 600,
      height: 600,
      subdivisions: 4,
    }, this.scene);

    water.position.y = 0.0; // Nivel del mar a Y=0

    const waterMat = new StandardMaterial("matWater", this.scene);
    waterMat.diffuseColor = new Color3(0.1, 0.55, 0.72);
    waterMat.specularColor = new Color3(0.6, 0.9, 1.0);
    waterMat.alpha = 0.78;
    water.material = waterMat;

    return water;
  }

  // Renderizar o actualizar nodos de recursos (Árboles, Rocas, Arbustos)
  public syncResourceNode(id: string, type: string, x: number, y: number, z: number, available: boolean) {
    let mesh = this.resourceMeshes.get(id);

    if (!mesh) {
      mesh = this.buildResourceMesh(type);
      mesh.position.set(x, y, z);
      this.resourceMeshes.set(id, mesh);
      this.shadowGenerator.addShadowCaster(mesh);
    }

    mesh.setEnabled(available);
  }

  private buildResourceMesh(type: string): Mesh {
    if (type === "tree") {
      const root = new Mesh("treeRoot", this.scene);

      // Tronco
      const trunk = MeshBuilder.CreateCylinder("trunk", {
        height: 3.5,
        diameterTop: 0.45,
        diameterBottom: 0.65,
        tessellation: 7,
      }, this.scene);
      trunk.position.y = 1.75;
      const trunkMat = new StandardMaterial("matTrunk", this.scene);
      trunkMat.diffuseColor = new Color3(0.38, 0.24, 0.14);
      trunk.material = trunkMat;
      trunk.parent = root;

      // Copa estilizada de hojas (2 niveles de cono/icosaedro)
      const foliage1 = MeshBuilder.CreatePolyhedron("foliage1", { type: 2, size: 2.2 }, this.scene);
      foliage1.position.y = 4.2;
      const leafMat = new StandardMaterial("matLeaves", this.scene);
      leafMat.diffuseColor = new Color3(0.22, 0.62, 0.28);
      foliage1.material = leafMat;
      foliage1.parent = root;

      const foliage2 = MeshBuilder.CreatePolyhedron("foliage2", { type: 2, size: 1.6 }, this.scene);
      foliage2.position.y = 5.6;
      foliage2.material = leafMat;
      foliage2.parent = root;

      return root;
    } else if (type === "rock") {
      const rock = MeshBuilder.CreatePolyhedron("rockMesh", { type: 1, size: 1.1 }, this.scene);
      rock.position.y = 0.8;
      const rockMat = new StandardMaterial("matRock", this.scene);
      rockMat.diffuseColor = new Color3(0.5, 0.52, 0.55);
      rock.material = rockMat;
      return rock;
    } else {
      // Arbusto de bayas
      const bush = MeshBuilder.CreateSphere("bushMesh", { diameter: 1.4, segments: 6 }, this.scene);
      bush.position.y = 0.7;
      const bushMat = new StandardMaterial("matBush", this.scene);
      bushMat.diffuseColor = new Color3(0.2, 0.5, 0.25);
      bush.material = bushMat;
      return bush;
    }
  }

  // Renderizar o actualizar estructuras (Fogatas)
  public syncStructure(id: string, type: string, x: number, y: number, z: number, rotY: number) {
    let mesh = this.structureMeshes.get(id);
    if (!mesh) {
      mesh = this.buildStructureMesh(type);
      mesh.position.set(x, y, z);
      mesh.rotation.y = rotY;
      this.structureMeshes.set(id, mesh);
      this.shadowGenerator.addShadowCaster(mesh);
    }
  }

  private buildStructureMesh(type: string): Mesh {
    const root = new Mesh("structRoot", this.scene);

    if (type === "campfire") {
      // Base de piedras circulares
      for (let i = 0; i < 6; i++) {
        const ang = (i / 6) * Math.PI * 2;
        const stone = MeshBuilder.CreateSphere("stoneBase" + i, { diameter: 0.35, segments: 5 }, this.scene);
        stone.position.set(Math.cos(ang) * 0.5, 0.15, Math.sin(ang) * 0.5);
        const stMat = new StandardMaterial("matSt" + i, this.scene);
        stMat.diffuseColor = new Color3(0.35, 0.35, 0.35);
        stone.material = stMat;
        stone.parent = root;
      }

      // Troncos en X
      const wood1 = MeshBuilder.CreateCylinder("log1", { height: 0.8, diameter: 0.15 }, this.scene);
      wood1.rotation.z = Math.PI / 4;
      wood1.position.y = 0.2;
      const wMat = new StandardMaterial("matWood", this.scene);
      wMat.diffuseColor = new Color3(0.4, 0.25, 0.15);
      wood1.material = wMat;
      wood1.parent = root;

      // Fuego brillante
      const fire = MeshBuilder.CreatePolyhedron("fireMesh", { type: 2, size: 0.35 }, this.scene);
      fire.position.y = 0.35;
      const fireMat = new StandardMaterial("matFire", this.scene);
      fireMat.diffuseColor = new Color3(1.0, 0.5, 0.1);
      fireMat.emissiveColor = new Color3(1.0, 0.4, 0.05);
      fire.material = fireMat;
      fire.parent = root;
    }

    return root;
  }
}

// Helper para tipos de vertex data
const VertexBuffer = {
  PositionKind: "position",
  NormalKind: "normal",
  ColorKind: "color",
};
