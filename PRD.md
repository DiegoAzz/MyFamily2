# PRD 1.0 — WILDBORN ONLINE
## Videojuego indie de supervivencia 3D multijugador para navegador
**Destino:** Google Antigravity IDE | **Infraestructura:** Coolify sobre VPS | **Idioma del producto:** Español (i18n preparada para inglés) | **Fecha:** 22 de octubre de 2026

> **Principio rector:** entregar primero una partida real con dos jugadores en navegadores y redes diferentes, servidor autoritativo y un bucle básico de supervivencia. No sustituir funcionalidades con pantallas simuladas. Cada fase debe quedar ejecutable, verificable y desplegable.

---

## 1. Resumen ejecutivo
Crear **Wildborn Online**, un videojuego indie 3D cooperativo de supervivencia con arte estilizado de alta calidad, jugable sin instalar programas desde una URL HTTPS. Cada partida ocurre en una isla persistente instanciada, con hasta **16 jugadores simultáneos por instancia como objetivo de capacidad**, sujeto a pruebas reales. Exploración en tercera persona, recolección, crafteo, construcción, hambre, sed, salud, ciclo día/noche, fauna hostil, chat y grupos.

**Importante:** el navegador ejecuta/renderiza el videojuego localmente, no el VPS. El VPS aloja lógica, sincronización, cuentas, persistencia y archivos. No se promete 4K/60 FPS en todos los equipos; los ajustes visuales se adaptarán al hardware. Los recursos artísticos deben proceder de assets originales, de licencias compatibles o creados para el proyecto.

### Definiciones del producto
- **MVP vertical:** 2–4 jugadores conectados, movimiento y animaciones replicados, recolección autoritativa, inventario, colocación de una estructura, persistencia y sesión que sobrevive una reconexión.
- **V1 pública:** hasta 16 jugadores por isla, contenido base completo, chat y progreso persistente.
- **Fuera del alcance inicial:** MMO de miles de jugadores en un único mundo, PvP competitivo, economía de dinero real, NFT, streaming/cloud gaming, generación infinita del mapa y fotorrealismo AAA.

## 2. Visión y experiencia
**Fantasía:** despertar en una isla cubierta por bosques, playas, ruinas y animales; construir una base y superar amenazas con amigos.

**Bucle principal:** entrar → explorar → recolectar madera/piedra/comida → fabricar herramientas → construir refugio → gestionar hambre/sed → enfrentar criaturas → mejorar base y equipo → regresar y encontrar el progreso guardado.

**Jugadores objetivo:** fans de supervivencia cooperativa accesible desde PC; inicialmente teclado + mouse, escritorio. Móviles y mandos se evalúan después. Jugabilidad en tercera persona, cámara orbitante, sprint, salto, interacción contextual.

## 3. Alcance funcional y prioridades
### P0 — MVP obligatorio
1. Pantalla de inicio (crear cuenta, iniciar sesión, invitado solo en entorno de pruebas), elección de personaje y menú de salas.
2. Crear, listar y unirse a una isla mediante código o invitación; salas públicas/privadas; máximo 4 durante el MVP.
3. Escena 3D real con terreno, colisiones, árboles, rocas, cielo, agua sencilla, iluminación, niebla y un personaje con animaciones idle/caminar/correr/saltar.
4. Movimiento en tercera persona (WASD), cámara con mouse, Pointer Lock, salto, colisiones y límites del mapa.
5. Multiplayer real con un servidor autoritativo: dos personas se ven moverse con interpolación en redes diferentes; no dependemos de que una pestaña sea host.
6. Recolección de madera/piedra con tiempo de interacción, distancia y cantidad validados por servidor.
7. Inventario de 20 espacios, apilamiento y persistencia en PostgreSQL.
8. Elaboración de hacha básica y fogata; consumo de recursos validado atómicamente.
9. Colocación de una fogata o pared, validación de posición y persistencia.
10. Salud, hambre y sed que evolucionan en el servidor; al morir, reaparición definida.
11. HUD con barras, inventario, barra rápida, minimapa simple/indicador de dirección, estado de conexión y ajustes gráficos.
12. Reconexión controlada (sin duplicación de inventario) y retorno a la isla con estado persistido.
13. Docker Compose compatible con Coolify, HTTPS/WSS, migraciones, health checks, logs y scripts de respaldo.

### P1 — V1 jugable
- Mundo más amplio dividido en zonas: costa, selva, colinas, ruinas.
- 16 jugadores por sala como objetivo medido; varias salas independientes.
- Sistema de construcción modular: suelo, pared, puerta, techo y cofres; límites de área y permisos de equipo.
- Crafteo ampliado: pico, lanza, vendajes, fogata, armadura sencilla.
- Criaturas con IA server-side (patrulla/persecución/ataque), botín y respawn.
- Combate PvE con ataques, daño, cooldown, distancia y muerte verificados en servidor.
- Chat de texto por sala y equipo, muteo, reportes y moderación.
- Equipos/grupos, invitación y permisos de construcciones.
- Ciclo día/noche y clima visual; sincronizar hora y eventos determinantes desde servidor.
- Perfil de personaje, progreso y estadísticas, ajustes de sonido y accesibilidad.

### P2 — Después de la validación pública
- Eventos cooperativos y jefes, agricultura, pesca, biomas extra, cosméticos, logros, mando, localización inglesa y optimizaciones móviles.
- Voz en proximidad solo tras análisis de costes, privacidad y moderación. Si se implementa, usar un servicio WebRTC/SFU específico; no mezclar el tráfico de voz con el loop autoritativo del juego.

## 4. Arquitectura de referencia
```text
Navegador PC
  ├─ React + Vite + TypeScript (menús, HUD)
  ├─ Babylon.js (escena, cámara, audio, render, físicas cliente)
  └─ Colyseus SDK (WSS, inputs y sincronización)
          │ HTTPS / WSS
          ▼
Traefik / reverse proxy de Coolify
  ├─ web: sitio estático
  ├─ api: cuentas, perfiles, mundos, administración
  └─ game-server: Colyseus, salas e instancias autoritativas
           ├─ PostgreSQL: cuentas, inventario, progreso, mundos persistidos
           ├─ Redis: presencia/coordinación opcional (preparado, no obligatorio MVP)
           └─ Object storage: assets, backups según configuración
```

## 5. Red multijugador y netcode
- Salas independientes por isla; identificador UUID, capacidad y privacidad.
- Cliente envía intenciones de movimiento con secuencia y timestamp.
- Servidor simula a tick fijo (20-30 Hz) y emite snapshots optimizados.
- Cliente aplica predicción local e interpolación de entidades remotas.
