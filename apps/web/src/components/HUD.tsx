import React from "react";
import { Heart, Utensils, Droplets, Users, Wifi, Compass } from "lucide-react";

interface HUDProps {
  islandName: string;
  playerCount: number;
  ping: number;
  health: number;
  hunger: number;
  thirst: number;
  posX: number;
  posZ: number;
  inventory: Record<string, number>;
  onBuildCampfire: () => void;
  notification: string | null;
}

export const HUD: React.FC<HUDProps> = ({
  islandName,
  playerCount,
  ping,
  health,
  hunger,
  thirst,
  posX,
  posZ,
  inventory,
  onBuildCampfire,
  notification,
}) => {
  return (
    <div className="absolute inset-0 pointer-events-none flex flex-col justify-between p-4 z-10">
      {/* 1. Header Superior */}
      <div className="flex justify-between items-start">
        {/* Información de la Sala */}
        <div className="bg-slate-900/85 backdrop-blur-md border border-slate-700/80 rounded-xl px-4 py-2.5 flex items-center space-x-4 shadow-xl">
          <div className="flex flex-col">
            <span className="text-emerald-400 font-bold text-sm tracking-wide flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
              {islandName}
            </span>
            <div className="flex items-center space-x-3 text-xs text-slate-400 mt-0.5">
              <span className="flex items-center gap-1">
                <Users className="w-3.5 h-3.5 text-blue-400" />
                {playerCount} {playerCount === 1 ? "jugador" : "jugadores"}
              </span>
              <span>•</span>
              <span className="flex items-center gap-1">
                <Wifi className="w-3.5 h-3.5 text-emerald-400" />
                {ping} ms
              </span>
            </div>
          </div>
        </div>

        {/* Notificación flotante central si hay recolección */}
        {notification && (
          <div className="bg-amber-500/90 text-slate-950 font-bold px-4 py-2 rounded-lg shadow-lg border border-amber-300 animate-bounce">
            {notification}
          </div>
        )}

        {/* Brújula y Coordenadas */}
        <div className="bg-slate-900/85 backdrop-blur-md border border-slate-700/80 rounded-xl px-3.5 py-2 flex items-center space-x-2 text-xs text-slate-300 font-mono shadow-xl">
          <Compass className="w-4 h-4 text-emerald-400" />
          <span>X: {posX.toFixed(0)}</span>
          <span>Z: {posZ.toFixed(0)}</span>
        </div>
      </div>

      {/* 2. Barra Inferior: Estado de Supervivencia y Hotbar */}
      <div className="flex flex-col sm:flex-row justify-between items-end gap-4">
        {/* Barras de Supervivencia */}
        <div className="bg-slate-900/90 backdrop-blur-md border border-slate-700/80 rounded-2xl p-3.5 shadow-2xl w-64 space-y-2.5">
          {/* Salud */}
          <div>
            <div className="flex justify-between text-xs font-semibold mb-1">
              <span className="flex items-center gap-1.5 text-red-400">
                <Heart className="w-3.5 h-3.5 fill-red-400" /> Salud
              </span>
              <span className="text-slate-300 font-mono">{Math.round(health)}%</span>
            </div>
            <div className="w-full bg-slate-950/80 rounded-full h-2.5 overflow-hidden border border-red-950">
              <div
                className="bg-gradient-to-r from-red-600 to-rose-500 h-full rounded-full transition-all duration-300"
                style={{ width: `${Math.max(0, Math.min(100, health))}%` }}
              ></div>
            </div>
          </div>

          {/* Hambre */}
          <div>
            <div className="flex justify-between text-xs font-semibold mb-1">
              <span className="flex items-center gap-1.5 text-amber-400">
                <Utensils className="w-3.5 h-3.5" /> Hambre
              </span>
              <span className="text-slate-300 font-mono">{Math.round(hunger)}%</span>
            </div>
            <div className="w-full bg-slate-950/80 rounded-full h-2.5 overflow-hidden border border-amber-950">
              <div
                className="bg-gradient-to-r from-amber-600 to-yellow-500 h-full rounded-full transition-all duration-300"
                style={{ width: `${Math.max(0, Math.min(100, hunger))}%` }}
              ></div>
            </div>
          </div>

          {/* Sed */}
          <div>
            <div className="flex justify-between text-xs font-semibold mb-1">
              <span className="flex items-center gap-1.5 text-cyan-400">
                <Droplets className="w-3.5 h-3.5 fill-cyan-400" /> Sed
              </span>
              <span className="text-slate-300 font-mono">{Math.round(thirst)}%</span>
            </div>
            <div className="w-full bg-slate-950/80 rounded-full h-2.5 overflow-hidden border border-cyan-950">
              <div
                className="bg-gradient-to-r from-cyan-600 to-blue-500 h-full rounded-full transition-all duration-300"
                style={{ width: `${Math.max(0, Math.min(100, thirst))}%` }}
              ></div>
            </div>
          </div>
        </div>

        {/* Hotbar de Herramientas y Recursos */}
        <div className="flex flex-col items-center">
          {/* Instrucciones de Teclado */}
          <div className="text-[11px] font-medium text-slate-400 mb-2 flex items-center space-x-3 bg-slate-900/80 px-3 py-1 rounded-full border border-slate-700/50">
            <span>[E] Recolectar</span>
            <span>•</span>
            <span>[B] Construir Fogata</span>
            <span>•</span>
            <span>[Click] Mirar / Cursor</span>
          </div>

          <div className="bg-slate-900/90 backdrop-blur-md border border-slate-700/80 rounded-2xl p-2 shadow-2xl flex items-center space-x-2 pointer-events-auto">
            {/* Madera */}
            <div className="w-14 h-14 bg-slate-950/90 border border-slate-700 rounded-xl flex flex-col items-center justify-center relative hover:border-emerald-500 transition-colors">
              <span className="text-2xl">🪵</span>
              <span className="absolute bottom-1 right-1.5 text-[11px] font-bold text-amber-300 font-mono">
                {inventory.wood || 0}
              </span>
              <span className="absolute top-0.5 left-1 text-[9px] text-slate-500">1</span>
            </div>

            {/* Piedra */}
            <div className="w-14 h-14 bg-slate-950/90 border border-slate-700 rounded-xl flex flex-col items-center justify-center relative hover:border-emerald-500 transition-colors">
              <span className="text-2xl">🪨</span>
              <span className="absolute bottom-1 right-1.5 text-[11px] font-bold text-slate-300 font-mono">
                {inventory.stone || 0}
              </span>
              <span className="absolute top-0.5 left-1 text-[9px] text-slate-500">2</span>
            </div>

            {/* Bayas */}
            <div className="w-14 h-14 bg-slate-950/90 border border-slate-700 rounded-xl flex flex-col items-center justify-center relative hover:border-emerald-500 transition-colors">
              <span className="text-2xl">🍓</span>
              <span className="absolute bottom-1 right-1.5 text-[11px] font-bold text-rose-300 font-mono">
                {inventory.berries || 0}
              </span>
              <span className="absolute top-0.5 left-1 text-[9px] text-slate-500">3</span>
            </div>

            {/* Fogata Construible */}
            <button
              onClick={onBuildCampfire}
              className="w-14 h-14 bg-amber-950/40 border border-amber-600/70 hover:bg-amber-600/30 rounded-xl flex flex-col items-center justify-center relative active:scale-95 transition-all cursor-pointer group"
              title="Construir Fogata (Tecla B)"
            >
              <span className="text-2xl group-hover:scale-110 transition-transform">🔥</span>
              <span className="text-[9px] font-bold text-amber-400 mt-0.5">Fogata</span>
              <span className="absolute top-0.5 left-1 text-[9px] text-amber-500">B</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
