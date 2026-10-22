import React, { useState, useRef, useEffect } from "react";
import { MessageSquare, Send } from "lucide-react";
import { ChatMessagePayload } from "@wildborn/shared";

interface ChatBoxProps {
  messages: ChatMessagePayload[];
  onSendMessage: (text: string) => void;
}

export const ChatBox: React.FC<ChatBoxProps> = ({ messages, onSendMessage }) => {
  // En móviles inicia cerrado para no tapar la pantalla 3D
  const [isOpen, setIsOpen] = useState(() =>
    typeof window !== "undefined" ? window.innerWidth >= 768 : true
  );
  const [inputText, setInputText] = useState("");
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (inputText.trim().length > 0) {
      onSendMessage(inputText);
      setInputText("");
    }
  };

  return (
    <div className="absolute top-2 sm:top-4 right-20 sm:right-auto sm:left-64 pointer-events-auto z-30 w-72 sm:w-80 max-w-[calc(100vw-1rem)]">
      {/* Botón de alternar chat */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="bg-slate-900/85 hover:bg-slate-800 text-[10px] sm:text-xs text-slate-300 font-semibold px-2.5 py-1.5 rounded-xl border border-slate-700/80 flex items-center gap-1.5 backdrop-blur-md shadow-xl cursor-pointer transition-all active:scale-95 touch-manipulation ml-auto sm:ml-0"
      >
        <MessageSquare className="w-3.5 h-3.5 text-emerald-400" />
        {isOpen ? "Ocultar Chat" : `Chat (${messages.length})`}
      </button>

      {/* Contenedor del Chat */}
      {isOpen && (
        <div className="mt-1.5 bg-slate-900/95 backdrop-blur-md border border-slate-700/80 rounded-xl sm:rounded-2xl shadow-2xl p-2.5 sm:p-3 flex flex-col h-44 sm:h-56">
          {/* Mensajes */}
          <div ref={scrollRef} className="flex-1 overflow-y-auto space-y-1 sm:space-y-1.5 pr-1 text-[11px] sm:text-xs">
            {messages.length === 0 && (
              <p className="text-slate-500 italic">No hay mensajes aún en la isla...</p>
            )}
            {messages.map((msg, idx) => (
              <div key={idx} className="leading-relaxed break-words">
                <span
                  className={`font-bold mr-1.5 ${
                    msg.senderId === "system"
                      ? "text-amber-400"
                      : "text-emerald-400"
                  }`}
                >
                  {msg.senderName}:
                </span>
                <span className="text-slate-200">{msg.text}</span>
              </div>
            ))}
          </div>

          {/* Formulario de Entrada */}
          <form onSubmit={handleSubmit} className="mt-2 flex gap-1.5">
            <input
              type="text"
              value={inputText}
              onChange={(e) => setInputText(e.target.value)}
              placeholder="Escribe en la isla..."
              maxLength={90}
              className="flex-1 bg-slate-950/90 border border-slate-700 rounded-lg sm:rounded-xl px-2.5 py-1.5 text-sm sm:text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 transition-colors"
            />
            <button
              type="submit"
              className="bg-emerald-600 hover:bg-emerald-500 active:bg-emerald-700 text-white p-2 rounded-lg sm:rounded-xl flex items-center justify-center transition-colors cursor-pointer"
            >
              <Send className="w-3.5 h-3.5" />
            </button>
          </form>
        </div>
      )}
    </div>
  );
};
