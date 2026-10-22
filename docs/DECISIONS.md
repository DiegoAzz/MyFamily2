# DECISIONES ARQUITECTURALES Y TECNOLÓGICAS (ADR)
## Proyecto: Wildborn Online — Videojuego 3D Multijugador en Navegador
**Fecha:** 22 de octubre de 2026 | **Versión:** 1.0.0

---

### ADR 001: Gestor de Monorepo — npm Workspaces
* **Contexto:** Se requiere estructurar el proyecto en frontend (`apps/web`), backend API (`apps/api`), servidor de juego en tiempo real (`apps/game-server`), y paquetes compartidos (`packages/shared`, `packages/game-content`).
* **Decisión:** Utilizar **npm workspaces** nativo de Node.js.
* **Justificación:** Está soportado de forma estándar por Node.js v18/20/22+ sin requerir instalación de herramientas externas adicionales (como pnpm global) en entornos de integración continua (CI) o contenedores Docker en Coolify. Facilita builds reproducibles con `package-lock.json`.

---

### ADR 002: Motor de Render 3D — Babylon.js (Modular @babylonjs/core)
* **Contexto:** El juego se ejecuta directamente en navegadores de escritorio sin plugins ni descargas, requiriendo render 3D estilizado de alta calidad (iluminación PBR, sombras dinámicas, agua, niebla, cielo procedural y cámara en tercera persona).
* **Decisión:** Emplear **Babylon.js 7.x** con importaciones modulares (`@babylonjs/core`, `@babylonjs/loaders`, `@babylonjs/materials`).
* **Justificación:**
  1. Excelente soporte para WebGL 2 con fallback documentado y soporte emergente para WebGPU.
  2. Sistema de cámaras orbitales en tercera persona y Pointer Lock maduro.
  3. Soporte nativo para carga y renderizado optimizado de modelos glTF/GLB.
  4. Facilidad de optimización mediante Thin Instances (vegetación densa), Mesh Pooling y Frustum Culling.

---

### ADR 003: Servidor de Juego en Tiempo Real — Colyseus 0.15.x
* **Contexto:** Se requiere simulación autoritativa del servidor a tick fijo (20–30 Hz), salas independientes por isla instanciada, sincronización delta eficiente de posiciones y atributos de supervivencia.
* **Decisión:** Utilizar **Colyseus 0.15+** en TypeScript.
* **Justificación:**
  1. Modelo de salas (`Room`) y estado sincronizado basado en esquemas (`Schema`) que sólo replica cambios (deltas), reduciendo masivamente el ancho de banda.
  2. Soporte nativo de reconexión con tiempo de gracia (`allowReconnection`).
  3. Ejecución directa en Node.js, compatible con proxies reversos (Traefik/Nginx en Coolify con WSS upgrade).
  4. El servidor tiene autoridad completa sobre movimientos, límites de mapa y consumo de recursos.

---

### ADR 004: Interfaz de Usuario y HUD — React + Vite + Tailwind CSS
* **Contexto:** Menús de inicio, selector de salas, HUD de supervivencia (salud, hambre, sed), inventario de 20 casillas y ventana de fabricación.
* **Decisión:** Desarrollar la capa de interfaz sobre **React + Vite**, superpuesta sobre el `<canvas>` de Babylon.js con `pointer-events: none` en áreas transparentes.
* **Justificación:**
  1. Separación limpia entre la lógica del motor 3D y la gestión de estados de interfaz reactivos.
  2. Estilizado rápido y responsivo con Tailwind CSS sin impactar el loop de render de 60 FPS de Babylon.js.

---

### ADR 005: Persistencia y Base de Datos — PostgreSQL + Prisma ORM
* **Contexto:** Almacenamiento seguro de cuentas de usuario (hashes Argon2id/bcrypt), personajes, mundos instanciados, inventarios por casilla y estructuras.
* **Decisión:** Emplear **PostgreSQL** con **Prisma ORM**.
* **Justificación:**
  1. Soporte estricto de transacciones ACID para evitar duplicación de items en recolección o crafteo simultáneo.
  2. Migraciones versionadas y declarativas (`prisma migrate`).
  3. Tipado automático en TypeScript para backend y servidor de juego.

---

### ADR 006: Despliegue e Infraestructura — Docker Compose para Coolify
* **Contexto:** Despliegue en VPS Linux administrado por Coolify, con certificados SSL automáticos y proxy Traefik.
* **Decisión:** Arquitectura multi-contenedor con `compose.yml`:
  - `web`: Build estático servido por Nginx ultraligero (`juego.midominio.com`).
  - `game-server`: Servicio Node.js persistente WebSocket (`play.midominio.com`).
  - `api`: API REST privada/pública para cuentas y mundos (`api.midominio.com`).
  - `postgres`: Base de datos relacional en red interna Docker con volumen persistente.
