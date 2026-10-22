export interface CraftingIngredient {
  itemId: string;
  count: number;
}

export interface CraftingRecipe {
  id: string;
  resultItemId: string;
  resultCount: number;
  craftTimeSeconds: number;
  ingredients: CraftingIngredient[];
}

export const RECIPES: Record<string, CraftingRecipe> = {
  stone_axe: {
    id: "stone_axe",
    resultItemId: "stone_axe",
    resultCount: 1,
    craftTimeSeconds: 2.0,
    ingredients: [
      { itemId: "wood", count: 10 },
      { itemId: "stone", count: 5 },
    ],
  },
  campfire: {
    id: "campfire",
    resultItemId: "campfire",
    resultCount: 1,
    craftTimeSeconds: 3.0,
    ingredients: [
      { itemId: "wood", count: 15 },
      { itemId: "stone", count: 10 },
    ],
  },
};
