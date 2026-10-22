export interface ItemDefinition {
  id: string;
  name: string;
  description: string;
  category: "resource" | "tool" | "food" | "structure";
  stackLimit: number;
  icon: string;
  foodValue?: number;
  waterValue?: number;
  damage?: number;
}

export const ITEMS: Record<string, ItemDefinition> = {
  wood: {
    id: "wood",
    name: "Madera",
    description: "Troncos recolectados de los árboles de la isla. Material básico para herramientas y refugios.",
    category: "resource",
    stackLimit: 50,
    icon: "🪵",
  },
  stone: {
    id: "stone",
    name: "Piedra",
    description: "Rocas sólidas de la cantera de la isla. Vital para herramientas y fogatas.",
    category: "resource",
    stackLimit: 50,
    icon: "🪨",
  },
  berries: {
    id: "berries",
    name: "Bayas Silvestres",
    description: "Frutos dulces recolectados de los arbustos costeros. Sacian el hambre y calman la sed.",
    category: "food",
    stackLimit: 30,
    icon: "🍓",
    foodValue: 15,
    waterValue: 10,
  },
  stone_axe: {
    id: "stone_axe",
    name: "Hacha de Piedra",
    description: "Herramienta rústica para talar árboles el doble de rápido.",
    category: "tool",
    stackLimit: 1,
    icon: "🪓",
    damage: 12,
  },
  campfire: {
    id: "campfire",
    name: "Fogata de Piedra",
    description: "Estructura que emite calor, luz en la noche y permite cocinar alimentos.",
    category: "structure",
    stackLimit: 5,
    icon: "🔥",
  },
};
