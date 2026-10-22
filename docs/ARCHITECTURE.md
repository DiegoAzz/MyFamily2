# ARQUITECTURA DEL SISTEMA — WILDBORN ONLINE
## Especificación de Componentes, Flujos de Datos y Seguridad
**Versión:** 1.0.0 | **Fecha:** 22 de octubre de 2026

---

### 1. Diagrama de Arquitectura

```mermaid
graph TD
    Client["Navegador Web (PC)
    • React + Vite
    • Babylon.js 3D Engine
    • Colyseus Client SDK"]
    
    Proxy["Coolify Reverse Proxy (Traefik)
    • Termina SSL (HTTPS / WSS)
    • Enrutamiento por subdominio/ruta"]
    
    WebStatic["apps/web (Nginx Container)
    • HTML5, Bundles JS/Wasm, Assets 3D"]
    
    API["apps/api (Node.js REST)
    • Auth / JWT
    • Perfiles de Personaje
    • Metadatos de Mundos"]
    
    GameServer["apps/game-server (Colyseus 0.15)
    • Tick autoritativo (20-30 Hz)
    • Simulación de física y colisiones
    • IslandRoom (Salas de 16 jugadores)
    • IA de Criaturas y Supervivencia"]
    
    DB[(PostgreSQL 16)
    • Cuentas y Personajes
    • Inventario y Slots
    • Estructuras y Mundos]
    
    Client -- "HTTPS: Descarga Assets" --> Proxy --> WebStatic
    Client -- "HTTPS: Registro/Login" --> Proxy --> API
    Client -- "WSS: Inputs y Sincronización" --> Proxy --> GameServer
    API -- "Prisma ORM" --> DB
    GameServer -- "Checkpoints y Persistencia" --> DB
```

---

### 2. Flujo de Sincronización Autoritativa

1. **Intención de Movimiento (Cliente):**
   - El cliente envía periódicamente `{ seq: number, input: { forward, strafe, jump, sprint }, yaw: number }`.
   - El cliente aplica predicción local inmediata para respuesta instantánea a 60 FPS.
2. **Validación del Servidor (Colyseus a 20-30 Hz):**
   - El servidor calcula la nueva posición basada en la velocidad permitida (`SPEED_WALK` o `SPEED_SPRINT`), gravedad y colisiones con el terreno/límites.
   - Si la posición del cliente se desvía más allá de un umbral tolerado, el servidor envía corrección autoritativa (Reconciliation).
3. **Replicación a Otros Jugadores:**
   - Colyseus emite deltas binarios optimizados.
   - Los clientes remotos reciben las posiciones y aplican interpolación lineal/esférica (LERP/SLERP) para movimiento fluido y natural.

---

### 3. Modelo de Seguridad
* **Sin Confianza en el Cliente:** La vida, el inventario, el daño infligido y la recolección se validan exclusivamente en el servidor.
* **Transacciones Atómicas:** Las acciones de crafteo e inventario ejecutan transacciones ACID en PostgreSQL para imposibilitar la clonación de items.
* **Secretos Protegidos:** Ni contraseñas ni claves de tokens residen en repositorios; se inyectan como variables de entorno seguras en Coolify.
