import React, { useState } from "react";
import { Play, Compass, Shield, Flame, TreePine, Users } from "lucide-react";

interface MainMenuProps {
  onStartGame: (playerName: string, roomCode: string) => void;
  isLoading: boolean;
  errorMessage: string | null;
}

export const MainMenu: React.FC<MainMenuProps> = ({
  onStartGame,
  isLoading,
  errorMessage,
}) => {
  const [playerName, setPlayerName] = useState("Nómada_" + Math.floor(Math.random() * 900 + 100));
  const [roomCode, setRoomCode] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (playerName.trim().length > 0 && !isLoading) {
      onStartGame(playerName.trim(), roomCode.trim());
    }
  };

  return (
    <div className="absolute inset-0 bg-slate-950/80 backdrop-blur-md flex items-center justify-center p-3 sm:p-4 z-50 overflow-y-auto">
      <div className="bg-slate-900/90 border border-slate-800 rounded-2xl sm:rounded-3xl p-5 sm:p-8 max-w-md w-full shadow-2xl relative overflow-hidden my-auto">
        {/* Glow de acento */}
        <div className="absolute -top-24 -left-24 w-48 h-48 bg-emerald-500/15 rounded-full blur-3xl pointer-events-none"></div>
        <div className="absolute -bottom-24 -right-24 w-48 h-48 bg-amber-500/15 rounded-full blur-3xl pointer-events-none"></div>

        {/* Título y Logo */}
        <div className="text-center mb-5 sm:mb-6 relative">
          <div className="inline-flex items-center justify-center w-12 h-12 sm:w-14 sm:h-14 rounded-2xl bg-gradient-to-tr from-emerald-600 to-teal-400 text-white shadow-lg mb-2.5 sm:mb-3">
            <Compass className="w-7 h-7 sm:w-8 sm:h-8" />
          </div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 via-teal-300 to-cyan-400 tracking-tight">
            WILDBORN ONLINE
          </h1>
          <p className="text-[11px] sm:text-xs text-slate-400 font-medium tracking-wide mt-1">
            Supervivencia 3D Cooperativa en la Isla
          </p>
        </div>

        {/* Mensaje de Error si lo hay */}
        {errorMessage && (
          <div className="mb-4 bg-rose-500/15 border border-rose-500/40 text-rose-300 text-xs px-3.5 py-2.5 rounded-xl">
            {errorMessage}
          </div>
        )}

        {/* Formulario */}
        <form onSubmit={handleSubmit} className="space-y-3 sm:space-y-4">
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">
              Tu Nombre de Explorador
            </label>
            <input
              type="text"
              value={playerName}
              onChange={(e) => setPlayerName(e.target.value)}
              maxLength={16}
              required
              className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2 sm:px-4 sm:py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all font-medium"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1 flex justify-between">
              <span>Código de Isla (Opcional)</span>
              <span className="text-slate-500 font-normal text-[11px]">Vacío = Sala Pública</span>
            </label>
            <input
              type="text"
              value={roomCode}
              onChange={(e) => setRoomCode(e.target.value)}
              placeholder="Ej: ISLA-01"
              maxLength={12}
              className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2 sm:px-4 sm:py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all font-mono"
            />
          </div>

          <button
            type="submit"
            disabled={isLoading || playerName.trim().length === 0}
            className="w-full bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-bold py-2.5 sm:py-3 px-6 rounded-xl shadow-lg shadow-emerald-950/50 flex items-center justify-center space-x-2 transition-all active:scale-[0.98] disabled:opacity-50 cursor-pointer mt-1"
          >
            {isLoading ? (
              <span className="flex items-center gap-2 text-xs sm:text-sm">
                <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
                Conectando a la isla...
              </span>
            ) : (
              <>
                <Play className="w-4 h-4 fill-white" />
                <span className="text-xs sm:text-sm">DESPERTAR EN LA ISLA</span>
              </>
            )}
          </button>
        </form>

        {/* Resumen de Controles */}
        <div className="mt-4 sm:mt-6 pt-4 sm:pt-5 border-t border-slate-800 text-[11px] text-slate-400 space-y-2">
          <p className="font-semibold text-slate-300 flex items-center gap-1.5">
            <Shield className="w-3.5 h-3.5 text-emerald-400" /> Controles Multiplataforma:
          </p>
          <div className="grid grid-cols-2 gap-x-2 gap-y-1 text-slate-400 font-mono text-[10px] sm:text-[11px]">
            <span>PC: [W,A,S,D] Moverse</span>
            <span>Móvil: Joystick táctil</span>
            <span>PC: [Shift] Correr</span>
            <span>Móvil: Botón Correr</span>
            <span>PC: [Espacio] Saltar</span>
            <span>Móvil: Botón Saltar</span>
            <span>PC: [E] Recolectar</span>
            <span>Móvil: Botón Acción</span>
            <span>PC: [B] Construir</span>
            <span>Móvil: Botón Fogata</span>
            <span>PC: Ratón / Click 3D</span>
            <span>Móvil: Deslizar pantalla</span>
          </div>
        </div>
      </div>
    </div>
  );
};
