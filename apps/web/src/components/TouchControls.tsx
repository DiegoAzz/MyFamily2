import React, { useRef, useState, useEffect, useCallback } from "react";
import { ArrowUp, Flame, Pickaxe, Zap } from "lucide-react";

interface TouchControlsProps {
  onMove: (forward: number, strafe: number) => void;
  onJump: () => void;
  onSprintToggle: (sprint: boolean) => void;
  onInteract: () => void;
  onBuild: () => void;
}

export const TouchControls: React.FC<TouchControlsProps> = ({
  onMove,
  onJump,
  onSprintToggle,
  onInteract,
  onBuild,
}) => {
  const [knobPos, setKnobPos] = useState({ x: 0, y: 0 });
  const [isSprintActive, setIsSprintActive] = useState(false);
  const joystickBaseRef = useRef<HTMLDivElement | null>(null);
  const touchIdRef = useRef<number | null>(null);
  const joyCenterRef = useRef({ x: 0, y: 0 });
  const maxRadius = 38; // Radio máximo de desplazamiento del joystick en px

  // Manejar movimiento del Joystick
  const handleTouchStart = (e: React.TouchEvent<HTMLDivElement>) => {
    if (touchIdRef.current !== null) return;
    const touch = e.changedTouches[0];
    touchIdRef.current = touch.identifier;

    if (joystickBaseRef.current) {
      const rect = joystickBaseRef.current.getBoundingClientRect();
      joyCenterRef.current = {
        x: rect.left + rect.width / 2,
        y: rect.top + rect.height / 2,
      };
      updateJoystick(touch.clientX, touch.clientY);
    }
  };

  const handleTouchMove = useCallback((e: TouchEvent) => {
    if (touchIdRef.current === null) return;
    for (let i = 0; i < e.changedTouches.length; i++) {
      const touch = e.changedTouches[i];
      if (touch.identifier === touchIdRef.current) {
        updateJoystick(touch.clientX, touch.clientY);
        break;
      }
    }
  }, []);

  const handleTouchEnd = useCallback((e: TouchEvent) => {
    if (touchIdRef.current === null) return;
    for (let i = 0; i < e.changedTouches.length; i++) {
      const touch = e.changedTouches[i];
      if (touch.identifier === touchIdRef.current) {
        touchIdRef.current = null;
        setKnobPos({ x: 0, y: 0 });
        onMove(0, 0);
        break;
      }
    }
  }, [onMove]);

  const updateJoystick = (clientX: number, clientY: number) => {
    const dx = clientX - joyCenterRef.current.x;
    const dy = clientY - joyCenterRef.current.y;
    const dist = Math.hypot(dx, dy);

    let clampedX = dx;
    let clampedY = dy;

    if (dist > maxRadius) {
      clampedX = (dx / dist) * maxRadius;
      clampedY = (dy / dist) * maxRadius;
    }

    setKnobPos({ x: clampedX, y: clampedY });

    // Normalizar forward (-1 a 1) y strafe (-1 a 1)
    const strafe = clampedX / maxRadius;
    const forward = -clampedY / maxRadius;
    onMove(forward, strafe);
  };

  useEffect(() => {
    window.addEventListener("touchmove", handleTouchMove, { passive: false });
    window.addEventListener("touchend", handleTouchEnd);
    window.addEventListener("touchcancel", handleTouchEnd);

    return () => {
      window.removeEventListener("touchmove", handleTouchMove);
      window.removeEventListener("touchend", handleTouchEnd);
      window.removeEventListener("touchcancel", handleTouchEnd);
    };
  }, [handleTouchMove, handleTouchEnd]);

  const toggleSprint = () => {
    const nextState = !isSprintActive;
    setIsSprintActive(nextState);
    onSprintToggle(nextState);
  };

  return (
    <div className="absolute inset-0 pointer-events-none z-20 flex justify-between items-end p-2 pb-3 sm:p-4 sm:pb-6 select-none overflow-hidden">
      {/* 1. Joystick Virtual en la esquina inferior izquierda */}
      <div className="relative pointer-events-auto touch-none ml-1 mb-1 sm:ml-2 sm:mb-2">
        <div
          ref={joystickBaseRef}
          onTouchStart={handleTouchStart}
          className="w-28 h-28 sm:w-32 sm:h-32 rounded-full bg-slate-900/60 backdrop-blur-md border-2 border-slate-600/60 shadow-2xl flex items-center justify-center relative touch-none active:border-emerald-500/80 transition-colors"
        >
          {/* Ejes visuales del joystick */}
          <div className="absolute w-full h-[1px] bg-slate-700/40"></div>
          <div className="absolute h-full w-[1px] bg-slate-700/40"></div>

          {/* Perilla móvil del joystick */}
          <div
            className="w-12 h-12 sm:w-14 sm:h-14 rounded-full bg-gradient-to-tr from-emerald-600 to-teal-400 border-2 border-white/80 shadow-lg flex items-center justify-center pointer-events-none"
            style={{
              transform: `translate3d(${knobPos.x}px, ${knobPos.y}px, 0)`,
              transition: touchIdRef.current === null ? "transform 0.15s ease-out" : "none",
            }}
          >
            <div className="w-3.5 h-3.5 rounded-full bg-white/60"></div>
          </div>
        </div>
        <span className="block text-center text-[9px] sm:text-[10px] font-bold text-slate-400 mt-0.5 tracking-wider uppercase">
          Moverse
        </span>
      </div>

      {/* 2. Botones de Acción Táctiles en la esquina inferior derecha */}
      <div className="pointer-events-auto flex flex-col items-end gap-2 sm:gap-3 mr-1 mb-1 sm:mr-2 sm:mb-2">
        {/* Fila superior de acciones: Recolectar y Fogata */}
        <div className="flex gap-2 sm:gap-2.5">
          {/* Botón Construir Fogata (B) */}
          <button
            onTouchStart={(e) => {
              e.preventDefault();
              onBuild();
            }}
            onClick={onBuild}
            className="w-11 h-11 sm:w-13 sm:h-13 rounded-xl sm:rounded-2xl bg-amber-950/80 active:bg-amber-700 border-2 border-amber-500/70 text-amber-300 shadow-xl flex flex-col items-center justify-center active:scale-90 transition-all touch-manipulation"
            title="Construir Fogata"
          >
            <Flame className="w-4 h-4 sm:w-5 sm:h-5" />
            <span className="text-[8px] sm:text-[9px] font-bold sm:mt-0.5">Fogata</span>
          </button>

          {/* Botón Recolectar / Interactuar (E) */}
          <button
            onTouchStart={(e) => {
              e.preventDefault();
              onInteract();
            }}
            onClick={onInteract}
            className="w-12 h-12 sm:w-14 sm:h-14 rounded-xl sm:rounded-2xl bg-emerald-950/80 active:bg-emerald-600 border-2 border-emerald-400 text-emerald-200 shadow-xl flex flex-col items-center justify-center active:scale-90 transition-all touch-manipulation"
            title="Recolectar / Interactuar"
          >
            <Pickaxe className="w-5 h-5 sm:w-6 sm:h-6" />
            <span className="text-[8px] sm:text-[9px] font-bold sm:mt-0.5">Acción</span>
          </button>
        </div>

        {/* Fila inferior de locomoción: Sprint Toggle y Salto */}
        <div className="flex gap-2 sm:gap-3 items-center">
          {/* Botón Alternar Correr (Sprint / Shift) */}
          <button
            onTouchStart={(e) => {
              e.preventDefault();
              toggleSprint();
            }}
            onClick={toggleSprint}
            className={`w-11 h-11 sm:w-13 sm:h-13 rounded-xl sm:rounded-2xl border-2 flex flex-col items-center justify-center active:scale-90 transition-all shadow-xl touch-manipulation ${
              isSprintActive
                ? "bg-amber-500 border-amber-300 text-slate-950 font-extrabold shadow-amber-500/40"
                : "bg-slate-900/80 active:bg-slate-800 border-slate-600/70 text-slate-300"
            }`}
            title="Alternar Correr"
          >
            <Zap className={`w-4 h-4 sm:w-5 sm:h-5 ${isSprintActive ? "fill-slate-950" : ""}`} />
            <span className="text-[8px] sm:text-[9px] font-bold sm:mt-0.5">
              {isSprintActive ? "Rápido" : "Correr"}
            </span>
          </button>

          {/* Botón de Salto (Espacio) */}
          <button
            onTouchStart={(e) => {
              e.preventDefault();
              onJump();
            }}
            onClick={onJump}
            className="w-14 h-14 sm:w-16 sm:h-16 rounded-full bg-gradient-to-tr from-cyan-600 to-blue-500 active:from-cyan-500 active:to-blue-400 border-2 border-cyan-300 text-white shadow-2xl flex flex-col items-center justify-center active:scale-90 transition-all touch-manipulation"
            title="Saltar"
          >
            <ArrowUp className="w-6 h-6 sm:w-7 sm:h-7 stroke-[2.5]" />
            <span className="text-[8px] sm:text-[9px] font-extrabold tracking-wider uppercase">Saltar</span>
          </button>
        </div>
      </div>
    </div>
  );
};
