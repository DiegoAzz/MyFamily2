export const GAME_CONSTANTS = {
  // Simulación y Red
  SERVER_TICK_RATE: 20, // 20 Hz = 50ms por tick
  SERVER_TICK_DELTA: 1 / 20, // 0.05 segundos
  MAX_PLAYERS_PER_ROOM: 16,
  MVP_MAX_PLAYERS: 4,
  RECONNECT_TIMEOUT_SEC: 15,

  // Límites del Mundo (Isla)
  ISLAND_RADIUS: 120.0, // Radio circular seguro de la isla
  OCEAN_KILL_DEPTH: -15.0, // Altura Y a la que se considera ahogado
  SPAWN_AREA_RADIUS: 15.0, // Radio de spawn aleatorio en la costa

  // Movimiento del Jugador
  PLAYER_WALK_SPEED: 4.5, // m/s
  PLAYER_SPRINT_SPEED: 7.8, // m/s
  PLAYER_JUMP_FORCE: 6.5, // velocidad vertical inicial al saltar
  GRAVITY: 18.0, // aceleración de gravedad (m/s^2)
  PLAYER_HEIGHT: 1.8,
  PLAYER_RADIUS: 0.4,

  // Supervivencia (Decay por segundo)
  MAX_HEALTH: 100,
  MAX_HUNGER: 100,
  MAX_THIRST: 100,
  HUNGER_DECAY_RATE: 0.12, // ~14 minutos de 100 a 0
  THIRST_DECAY_RATE: 0.22, // ~7.5 minutos de 100 a 0
  STARVATION_DAMAGE_RATE: 1.5, // Daño a la salud por segundo sin comida/agua

  // Ciclo Día / Noche
  DAY_DURATION_SEC: 600, // 10 minutos por día completo
} as const;
