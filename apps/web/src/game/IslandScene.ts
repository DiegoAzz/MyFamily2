import {
  Engine,
  Scene,
  Vector3,
  Color3,
  Color4,
  HemisphericLight,
  DirectionalLight,
  PointLight,
  ShadowGenerator,
  MeshBuilder,
  StandardMaterial,
  VertexData,
  VertexBuffer,
  Mesh,
  TransformNode,
  DynamicTexture,
  ArcRotateCamera,
  DefaultRenderingPipeline,
  ParticleSystem,
  Texture,
} from "@babylonjs/core";
import { GAME_CONSTANTS } from "@wildborn/shared";

export class IslandScene {
  public engine: Engine;
  public scene: Scene;
  public terrainMesh: Mesh;
  public waterMesh: Mesh;
  public foamMesh: Mesh;
  public shadowGenerator: ShadowGenerator;
  public sunLight: DirectionalLight;
  public ambientLight: HemisphericLight;
  public pipeline: DefaultRenderingPipeline;

  private resourceMeshes = new Map<string, Mesh>();
  private structureMeshes = new Map<string, Mesh>();
  private clouds: Mesh[] = [];
  private campfireParticles = new Map<string, ParticleSystem>();
  private campfireLights = new Map<string, PointLight>();

  private animTime: number = 0;

  constructor(canvas: HTMLCanvasElement) {
    this.engine = new Engine(canvas, true, {
      preserveDrawingBuffer: true,
      stencil: true,
      adaptToDeviceRatio: true,
      powerPreference: "high-performance",
    });

    this.scene = new Scene(this.engine);
    // Cielo tropical brillante y despejado
    this.scene.clearColor = new Color4(0.48, 0.76, 0.98, 1.0);
    this.scene.fogMode = Scene.FOGMODE_EXP2;
    this.scene.fogColor = new Color3(0.68, 0.85, 0.98);
    this.scene.fogDensity = 0.0028;

    // ==========================================
    // 1. ILUMINACIÓN CINEMATOGRÁFICA TROPICAL
    // ==========================================
    // Luz ambiental suave con relleno del cielo y rebote de hierba
    this.ambientLight = new HemisphericLight(
      "ambientLight",
      new Vector3(0, 1, 0),
      this.scene
    );
    this.ambientLight.diffuse = new Color3(0.92, 0.96, 1.0); // Luz del cielo azul
    this.ambientLight.groundColor = new Color3(0.24, 0.45, 0.22); // Rebote verde pradera
    this.ambientLight.intensity = 0.85;

    // Sol dorado tropical con sombras suaves
    this.sunLight = new DirectionalLight(
      "sunLight",
      new Vector3(-0.55, -0.85, -0.42).normalize(),
      this.scene
    );
    this.sunLight.diffuse = new Color3(1.0, 0.96, 0.86);
    this.sunLight.specular = new Color3(1.0, 0.98, 0.9);
    this.sunLight.intensity = 1.65;
    this.sunLight.position = new Vector3(90, 140, 90);

    // Generador de sombras de alta fidelidad
    this.shadowGenerator = new ShadowGenerator(2048, this.sunLight);
    this.shadowGenerator.useBlurExponentialShadowMap = true;
    this.shadowGenerator.blurKernel = 24;
    this.shadowGenerator.darkness = 0.45;

    // ==========================================
    // 2. CÚPULA CELESTE, SOL Y NUBES BAJAS
    // ==========================================
    this.createSkyAndClouds();

    // ==========================================
    // 3. TERRENO DETALLADO CON BIOMAS VIBRANTES
    // ==========================================
    this.terrainMesh = this.createIslandTerrain();
    this.terrainMesh.receiveShadows = true;

    // ==========================================
    // 4. DETALLES DE FLORA (HIERBA Y FLORES)
    // ==========================================
    this.createFoliageInstances();

    // ==========================================
    // 5. OCÉANO TURQUESA CON ESPUMA DE ORILLA
    // ==========================================
    const waterGroup = this.createOceanWater();
    this.waterMesh = waterGroup.water;
    this.foamMesh = waterGroup.foam;

    // ==========================================
    // 6. CÁMARA INICIAL PANORÁMICA
    // ==========================================
    const initialCamera = new ArcRotateCamera(
      "initialCamera",
      -Math.PI / 3,
      Math.PI / 2.7,
      85,
      new Vector3(0, 10, 0),
      this.scene
    );
    this.scene.activeCamera = initialCamera;

    // ==========================================
    // 7. PIPELINE DE POST-PROCESAMIENTO CINEMATOGRÁFICO
    // ==========================================
    this.pipeline = new DefaultRenderingPipeline(
      "cinematicPipeline",
      true, // HDR
      this.scene,
      [initialCamera]
    );
    this.pipeline.bloomEnabled = true;
    this.pipeline.bloomThreshold = 0.82;
    this.pipeline.bloomWeight = 0.32;
    this.pipeline.bloomKernel = 64;
    this.pipeline.bloomScale = 0.5;

    this.pipeline.fxaaEnabled = true;
    this.pipeline.imageProcessingEnabled = true;
    this.pipeline.imageProcessing.contrast = 1.15;
    this.pipeline.imageProcessing.exposure = 1.08;

    // Loop de render continuo y animaciones del mundo
    this.engine.runRenderLoop(() => {
      this.animTime += 0.016;

      // 1. Ondulación suave de la superficie del agua y espuma
      this.waterMesh.position.y = Math.sin(this.animTime * 1.6) * 0.07;
      this.foamMesh.scaling.set(
        1.0 + Math.sin(this.animTime * 1.6) * 0.015,
        1.0,
        1.0 + Math.sin(this.animTime * 1.6) * 0.015
      );

      // 2. Viento suave que hace derivar las nubes flotantes
      for (let i = 0; i < this.clouds.length; i++) {
        const cloud = this.clouds[i];
        cloud.position.x += 0.035;
        if (cloud.position.x > 320) {
          cloud.position.x = -320;
        }
      }

      // 3. Parpadeo orgánico de las luces de fogatas
      this.campfireLights.forEach((light) => {
        light.intensity = 1.4 + Math.sin(this.animTime * 14 + light.uniqueId) * 0.25;
      });

      if (this.scene.activeCamera) {
        this.scene.render();
      }
    });

    window.addEventListener("resize", () => {
      this.engine.resize();
    });
  }

  // Cúpula celeste, disco solar y nubes 3D estilizadas
  private createSkyAndClouds() {
    // 1. Cúpula celeste con gradiente azul cenit a cian horizonte
    const skyDome = MeshBuilder.CreateSphere(
      "skyDome",
      { diameter: 700, segments: 16, sideOrientation: Mesh.BACKSIDE },
      this.scene
    );
    const skyMat = new StandardMaterial("matSkyDome", this.scene);
    skyMat.emissiveColor = new Color3(0.52, 0.78, 0.98);
    skyMat.disableLighting = true;
    skyDome.material = skyMat;

    // 2. Disco solar dorado en el cielo
    const sunDisc = MeshBuilder.CreateSphere(
      "sunDisc",
      { diameter: 22, segments: 12 },
      this.scene
    );
    sunDisc.position.set(160, 240, 160);
    const sunMat = new StandardMaterial("matSunDisc", this.scene);
    sunMat.emissiveColor = new Color3(1.0, 0.98, 0.75);
    sunMat.disableLighting = true;
    sunDisc.material = sunMat;

    // 3. Nubes bajas y esponjosas (Estilo Low-Poly)
    const cloudMat = new StandardMaterial("matCloud", this.scene);
    cloudMat.diffuseColor = new Color3(1.0, 1.0, 1.0);
    cloudMat.emissiveColor = new Color3(0.85, 0.92, 0.98);
    cloudMat.specularColor = new Color3(0, 0, 0);

    const cloudPuffGeom = MeshBuilder.CreateSphere("puffBase", { diameter: 14, segments: 6 }, this.scene);
    cloudPuffGeom.setEnabled(false);

    for (let c = 0; c < 16; c++) {
      const cloudGroup = new Mesh(`cloud_${c}`, this.scene);
      const angle = (c / 16) * Math.PI * 2;
      const radius = 60 + Math.random() * 180;
      const x = Math.cos(angle) * radius;
      const z = Math.sin(angle) * radius;
      const y = 48 + Math.random() * 20;

      cloudGroup.position.set(x, y, z);

      // Crear racimo de 3 a 5 esferas interconectadas
      const puffs = 3 + Math.floor(Math.random() * 3);
      for (let p = 0; p < puffs; p++) {
        const puff = cloudPuffGeom.createInstance(`cloudPuff_${c}_${p}`);
        puff.position.set(
          (p - puffs / 2) * 8 + (Math.random() - 0.5) * 4,
          (Math.random() - 0.5) * 3,
          (Math.random() - 0.5) * 6
        );
        puff.scaling.set(
          1.0 + Math.random() * 0.4,
          0.7 + Math.random() * 0.3,
          0.9 + Math.random() * 0.5
        );
        puff.parent = cloudGroup;
      }

      this.clouds.push(cloudGroup);
    }
  }

  // Generación procedimental de la isla en 3D con biomas de colores ricos y textura estilizada
  private createIslandTerrain(): Mesh {
    const size = 260; // 260 x 260 metros
    const subdivisions = 128;
    const terrain = MeshBuilder.CreateGround(
      "islandTerrain",
      {
        width: size,
        height: size,
        subdivisions: subdivisions,
        updatable: true,
      },
      this.scene
    );

    const positions = terrain.getVerticesData(VertexBuffer.PositionKind)!;
    const colors: number[] = [];

    for (let i = 0; i < positions.length; i += 3) {
      const x = positions[i];
      const z = positions[i + 2];
      const height = this.calculateTerrainHeight(x, z);
      positions[i + 1] = height;

      // Coloración por altura con variaciones orgánicas
      const noise = (Math.sin(x * 0.15) + Math.cos(z * 0.15)) * 0.04;

      if (height < 1.35) {
        // Playa de arena cálida dorada (Costa caribeña)
        colors.push(0.96 + noise, 0.84 + noise, 0.54, 1.0);
      } else if (height < 2.4) {
        // Franja de transición arena-césped fresco
        colors.push(0.48 + noise, 0.86 + noise, 0.34, 1.0);
      } else if (height < 8.6) {
        // Pradera verde esmeralda exuberante
        colors.push(0.24 + noise, 0.76 + noise, 0.30, 1.0);
      } else {
        // Cima rocosa de granito pizarra (cumbre montañosa central)
        colors.push(0.48 + noise, 0.52 + noise, 0.56, 1.0);
      }
    }

    terrain.setVerticesData(VertexBuffer.PositionKind, positions);
    terrain.setVerticesData(VertexBuffer.ColorKind, colors);

    // Normales suaves
    const normals: number[] = [];
    VertexData.ComputeNormals(positions, terrain.getIndices()!, normals);
    terrain.setVerticesData(VertexBuffer.NormalKind, normals);

    // Textura procedural táctil estilizada de césped y micro-relieve
    const terrainTex = this.createTerrainTexture();

    // Material estilizado que fusiona la textura con los colores de los biomas
    const mat = new StandardMaterial("matTerrain", this.scene);
    mat.diffuseColor = new Color3(1, 1, 1);
    mat.diffuseTexture = terrainTex;
    mat.specularColor = new Color3(0.04, 0.04, 0.04); // Acabado mate no plástico
    terrain.material = mat;
    terrain.hasVertexAlpha = false;

    return terrain;
  }

  // Generador de textura procedural estilizada de micro-relieve táctil
  // Diseñada como mapa de detalle de alta frecuencia que modula los colores de vértices de cada bioma
  private createTerrainTexture(): DynamicTexture {
    const tex = new DynamicTexture("terrainTexture", { width: 512, height: 512 }, this.scene, true);
    const ctx = tex.getContext() as any;

    // Base blanca suave neutra
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, 512, 512);

    // Moteado orgánico y micro-detalles de textura táctil (grano de arena y briznas)
    for (let i = 0; i < 4500; i++) {
      const x = Math.random() * 512;
      const y = Math.random() * 512;
      const shade = Math.random();
      if (shade > 0.6) {
        ctx.fillStyle = "#ffffff";
      } else if (shade > 0.3) {
        ctx.fillStyle = "#f1f5f9";
      } else if (shade > 0.1) {
        ctx.fillStyle = "#e2e8f0";
      } else {
        ctx.fillStyle = "#cbd5e1";
      }
      ctx.fillRect(x, y, 1.5 + Math.random() * 2, 2 + Math.random() * 3);
    }

    tex.update();
    tex.uScale = 36;
    tex.vScale = 36;
    return tex;
  }

  // Hierba 3D y flores silvestres instanciadas en la pradera
  private createFoliageInstances() {
    // 1. Malla base de penacho de hierba (3 láminas cruzadas en estrella)
    const grassBase = new Mesh("grassBase", this.scene);
    const bladeMat = new StandardMaterial("matGrassBlade", this.scene);
    bladeMat.diffuseColor = new Color3(0.28, 0.78, 0.32);
    bladeMat.specularColor = new Color3(0, 0, 0);

    for (let b = 0; b < 3; b++) {
      const blade = MeshBuilder.CreatePlane(`blade_${b}`, { width: 0.65, height: 0.75 }, this.scene);
      blade.rotation.y = (b * Math.PI) / 3;
      blade.position.y = 0.37;
      blade.material = bladeMat;
      blade.parent = grassBase;
    }
    grassBase.setEnabled(false);

    // 2. Malla base de flor silvestre (pétalos coloridos con centro dorado)
    const flowerBase = new Mesh("flowerBase", this.scene);
    const flowerMat = new StandardMaterial("matFlowerPetals", this.scene);
    flowerMat.diffuseColor = new Color3(0.98, 0.35, 0.45); // Rosa carmín
    flowerMat.emissiveColor = new Color3(0.2, 0.05, 0.08);

    const petals = MeshBuilder.CreateDisc("flowerPetals", { radius: 0.22, tessellation: 6 }, this.scene);
    petals.rotation.x = Math.PI / 2;
    petals.position.y = 0.45;
    petals.material = flowerMat;
    petals.parent = flowerBase;

    const stem = MeshBuilder.CreateCylinder("flowerStem", { height: 0.45, diameter: 0.04 }, this.scene);
    stem.position.y = 0.22;
    stem.material = bladeMat;
    stem.parent = flowerBase;
    flowerBase.setEnabled(false);

    // Instanciar ~240 penachos de hierba en las zonas de pradera
    for (let i = 0; i < 240; i++) {
      const angle = Math.random() * Math.PI * 2;
      const radius = 12 + Math.random() * 80;
      const x = Math.cos(angle) * radius;
      const z = Math.sin(angle) * radius;
      const y = this.calculateTerrainHeight(x, z);

      // Solo en pradera (por encima de la playa y debajo de los peñascos)
      if (y > 1.8 && y < 7.5) {
        const grassInst = grassBase.clone(`grassInst_${i}`, null);
        if (grassInst) {
          grassInst.position.set(x, y, z);
          grassInst.rotation.y = Math.random() * Math.PI;
          const s = 0.75 + Math.random() * 0.5;
          grassInst.scaling.set(s, s, s);
          grassInst.setEnabled(true);
        }
      }
    }

    // Instanciar ~60 flores silvestres
    for (let f = 0; f < 60; f++) {
      const angle = Math.random() * Math.PI * 2;
      const radius = 14 + Math.random() * 75;
      const x = Math.cos(angle) * radius;
      const z = Math.sin(angle) * radius;
      const y = this.calculateTerrainHeight(x, z);

      if (y > 2.0 && y < 7.0) {
        const flowerInst = flowerBase.clone(`flowerInst_${f}`, null);
        if (flowerInst) {
          flowerInst.position.set(x, y, z);
          flowerInst.rotation.y = Math.random() * Math.PI;
          flowerInst.setEnabled(true);
        }
      }
    }
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

  // Océano Caribeño turquesa animado con anillo de espuma en la costa
  private createOceanWater(): { water: Mesh; foam: Mesh } {
    // 1. Superficie del mar traslúcida turquesa
    const water = MeshBuilder.CreateGround(
      "oceanWater",
      {
        width: 650,
        height: 650,
        subdivisions: 16,
      },
      this.scene
    );
    water.position.y = 0.0;

    const waterMat = new StandardMaterial("matWater", this.scene);
    waterMat.diffuseColor = new Color3(0.04, 0.68, 0.84); // Azul turquesa caribeño
    waterMat.specularColor = new Color3(0.95, 0.98, 1.0); // Destellos solares intensos
    waterMat.specularPower = 64;
    waterMat.alpha = 0.82;
    water.material = waterMat;

    // 2. Anillo de espuma blanca en la línea de orilla
    const foam = MeshBuilder.CreateDisc(
      "shoreFoam",
      {
        radius: 104,
        tessellation: 48,
        sideOrientation: Mesh.DOUBLESIDE,
      },
      this.scene
    );
    foam.rotation.x = Math.PI / 2;
    foam.position.y = 0.08;

    const foamMat = new StandardMaterial("matFoam", this.scene);
    foamMat.diffuseColor = new Color3(1.0, 1.0, 1.0);
    foamMat.emissiveColor = new Color3(0.9, 0.95, 1.0);
    foamMat.alpha = 0.35;
    foam.material = foamMat;

    return { water, foam };
  }

  // Sincronización de Recursos (Árboles, Rocas, Arbustos)
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

  // Construcción de mallas detalladas de estilo Low-Poly
  private buildResourceMesh(type: string): Mesh {
    if (type === "tree") {
      const root = new Mesh("treeRoot", this.scene);

      // Tronco estilizado con raíces ensanchadas
      const trunk = MeshBuilder.CreateCylinder(
        "trunk",
        {
          height: 3.8,
          diameterTop: 0.48,
          diameterBottom: 0.85,
          tessellation: 8,
        },
        this.scene
      );
      trunk.position.y = 1.9;
      const trunkMat = new StandardMaterial("matTrunk", this.scene);
      trunkMat.diffuseColor = new Color3(0.44, 0.28, 0.16);
      trunkMat.specularColor = new Color3(0.02, 0.02, 0.02);
      trunk.material = trunkMat;
      trunk.parent = root;

      // Copa de follaje multi-capa (Estilo Zelda/Forager)
      const foliageMat1 = new StandardMaterial("matLeaves1", this.scene);
      foliageMat1.diffuseColor = new Color3(0.18, 0.65, 0.28);
      foliageMat1.specularColor = new Color3(0.04, 0.04, 0.04);

      const foliageMat2 = new StandardMaterial("matLeaves2", this.scene);
      foliageMat2.diffuseColor = new Color3(0.24, 0.78, 0.34);
      foliageMat2.specularColor = new Color3(0.04, 0.04, 0.04);

      // Nivel 1 inferior (racimo amplio)
      const puff1 = MeshBuilder.CreateSphere("leafPuff1", { diameter: 2.8, segments: 7 }, this.scene);
      puff1.position.y = 3.6;
      puff1.material = foliageMat1;
      puff1.parent = root;

      // Nivel 2 medio (desplazado)
      const puff2 = MeshBuilder.CreateSphere("leafPuff2", { diameter: 2.3, segments: 7 }, this.scene);
      puff2.position.set(0.3, 4.8, -0.2);
      puff2.material = foliageMat2;
      puff2.parent = root;

      // Nivel 3 superior (punta)
      const puff3 = MeshBuilder.CreateSphere("leafPuff3", { diameter: 1.7, segments: 7 }, this.scene);
      puff3.position.set(-0.2, 5.9, 0.2);
      puff3.material = foliageMat1;
      puff3.parent = root;

      return root;
    } else if (type === "rock") {
      const root = new Mesh("rockCluster", this.scene);
      const rockMat = new StandardMaterial("matRock", this.scene);
      rockMat.diffuseColor = new Color3(0.55, 0.58, 0.62);
      rockMat.specularColor = new Color3(0.08, 0.08, 0.08);

      const mossMat = new StandardMaterial("matMoss", this.scene);
      mossMat.diffuseColor = new Color3(0.32, 0.68, 0.28);
      mossMat.specularColor = new Color3(0.02, 0.02, 0.02);

      // Peñasco principal facetado
      const mainRock = MeshBuilder.CreatePolyhedron("mainRock", { type: 1, size: 1.3 }, this.scene);
      mainRock.position.y = 0.9;
      mainRock.rotation.set(0.2, 0.5, 0.1);
      mainRock.material = rockMat;
      mainRock.parent = root;

      // Parche de musgo en la parte superior
      const mossCap = MeshBuilder.CreateDisc("mossCap", { radius: 0.65, tessellation: 6 }, this.scene);
      mossCap.rotation.x = Math.PI / 2;
      mossCap.position.set(0, 1.85, 0);
      mossCap.material = mossMat;
      mossCap.parent = root;

      // Roca pequeña compañera
      const sideRock = MeshBuilder.CreatePolyhedron("sideRock", { type: 2, size: 0.6 }, this.scene);
      sideRock.position.set(0.9, 0.45, 0.4);
      sideRock.material = rockMat;
      sideRock.parent = root;

      return root;
    } else {
      // Arbusto de bayas exuberante con frutos rojos
      const root = new Mesh("berryBushRoot", this.scene);

      const bushMat = new StandardMaterial("matBush", this.scene);
      bushMat.diffuseColor = new Color3(0.16, 0.58, 0.24);
      bushMat.specularColor = new Color3(0.02, 0.02, 0.02);

      const mainFoliage = MeshBuilder.CreateSphere("bushFoliage", { diameter: 1.6, segments: 7 }, this.scene);
      mainFoliage.position.y = 0.75;
      mainFoliage.scaling.set(1.1, 0.85, 1.0);
      mainFoliage.material = bushMat;
      mainFoliage.parent = root;

      // Racimos de bayas rojas brillantes
      const berryMat = new StandardMaterial("matBerry", this.scene);
      berryMat.diffuseColor = new Color3(0.95, 0.18, 0.26);
      berryMat.emissiveColor = new Color3(0.35, 0.04, 0.08);

      const berryPositions = [
        [0.6, 0.8, 0.4],
        [-0.5, 0.7, 0.5],
        [0.2, 1.1, -0.6],
        [-0.6, 0.8, -0.3],
        [0.5, 0.9, -0.4],
      ];

      berryPositions.forEach((pos, idx) => {
        const berry = MeshBuilder.CreateSphere(`berry_${idx}`, { diameter: 0.22, segments: 6 }, this.scene);
        berry.position.set(pos[0], pos[1], pos[2]);
        berry.material = berryMat;
        berry.parent = root;
      });

      return root;
    }
  }

  // Sincronización de Estructuras (Fogata de Supervivencia con Fuego Real)
  public syncStructure(id: string, type: string, x: number, y: number, z: number, rotY: number) {
    let mesh = this.structureMeshes.get(id);
    if (!mesh) {
      mesh = this.buildStructureMesh(id, type);
      mesh.position.set(x, y, z);
      mesh.rotation.y = rotY;
      this.structureMeshes.set(id, mesh);
      this.shadowGenerator.addShadowCaster(mesh);
    }
  }

  private buildStructureMesh(id: string, type: string): Mesh {
    const root = new Mesh("campfireRoot", this.scene);

    // 1. Círculo de 8 piedras redondas alrededor del fuego
    const stoneMat = new StandardMaterial("matCampfireStone", this.scene);
    stoneMat.diffuseColor = new Color3(0.42, 0.44, 0.46);

    for (let i = 0; i < 8; i++) {
      const angle = (i / 8) * Math.PI * 2;
      const stone = MeshBuilder.CreateSphere(
        `campStone_${i}`,
        { diameter: 0.38, segments: 6 },
        this.scene
      );
      stone.position.set(Math.cos(angle) * 0.75, 0.16, Math.sin(angle) * 0.75);
      stone.material = stoneMat;
      stone.parent = root;
    }

    // 2. Leños cruzados en el centro
    const woodMat = new StandardMaterial("matCampfireWood", this.scene);
    woodMat.diffuseColor = new Color3(0.24, 0.15, 0.1);

    for (let l = 0; l < 3; l++) {
      const log = MeshBuilder.CreateCylinder(
        `campLog_${l}`,
        { height: 0.9, diameter: 0.15, tessellation: 6 },
        this.scene
      );
      log.rotation.z = Math.PI / 3;
      log.rotation.y = (l * Math.PI) / 3;
      log.position.set(0, 0.22, 0);
      log.material = woodMat;
      log.parent = root;
    }

    // 3. Luz cálida oscilante de fuego
    const fireLight = new PointLight(`fireLight_${id}`, new Vector3(0, 0.6, 0), this.scene);
    fireLight.diffuse = new Color3(1.0, 0.55, 0.18);
    fireLight.intensity = 1.5;
    fireLight.range = 14;
    fireLight.parent = root;
    this.campfireLights.set(id, fireLight);

    // 4. Sistema de partículas de llamas y chispas
    const fireParticles = this.createFireParticleSystem(root);
    fireParticles.start();
    this.campfireParticles.set(id, fireParticles);

    return root;
  }

  // Generador de partículas de fuego procedural sin depender de imágenes externas
  private createFireParticleSystem(emitter: Mesh): ParticleSystem {
    const fire = new ParticleSystem("campfireFire", 100, this.scene);

    // Crear textura de partícula suave mediante DynamicTexture
    const particleTexture = new DynamicTexture("fireParticleTex", { width: 64, height: 64 }, this.scene, false);
    const ctx = particleTexture.getContext() as any;
    const grad = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
    grad.addColorStop(0, "rgba(255, 255, 255, 1.0)");
    grad.addColorStop(0.4, "rgba(255, 160, 20, 0.8)");
    grad.addColorStop(1, "rgba(255, 40, 0, 0)");
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, 64, 64);
    particleTexture.update();

    fire.particleTexture = particleTexture;
    fire.emitter = emitter;
    fire.minEmitBox = new Vector3(-0.2, 0.2, -0.2);
    fire.maxEmitBox = new Vector3(0.2, 0.3, 0.2);

    // Colores cálidos de fuego: blanco -> amarillo -> naranja -> rojo
    fire.color1 = new Color4(1.0, 0.9, 0.3, 1.0);
    fire.color2 = new Color4(1.0, 0.45, 0.1, 0.9);
    fire.colorDead = new Color4(0.8, 0.1, 0.05, 0.0);

    fire.minSize = 0.25;
    fire.maxSize = 0.55;
    fire.minLifeTime = 0.4;
    fire.maxLifeTime = 0.85;
    fire.emitRate = 45;
    fire.blendMode = ParticleSystem.BLENDMODE_ONEONE; // Brillo aditivo
    fire.gravity = new Vector3(0, 1.8, 0); // Fuego ascendente
    fire.direction1 = new Vector3(-0.2, 1.2, -0.2);
    fire.direction2 = new Vector3(0.2, 1.8, 0.2);
    fire.minEmitPower = 0.5;
    fire.maxEmitPower = 1.2;
    fire.updateSpeed = 0.02;

    return fire;
  }
}
