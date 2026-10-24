"use client";

import { useCallback } from "react";
import type { CollabColor } from "./colors";

export type CollabStatus =
  | "disabled"
  | "standby"
  | "connecting"
  | "reconnecting"
  | "connected"
  | "disconnected"
  | "error";

const DEFAULT_COLOR: CollabColor = {
  solid: "#10B981",
  translucent: "rgba(16, 185, 129, 0.22)",
};

export function useCollaboration(_options?: any) {
  const registerEditor = useCallback((_editor: any, _monaco: any) => {}, []);
  const unregisterEditor = useCallback((_editor: any) => {}, []);
  const undo = useCallback(() => false, []);
  const redo = useCallback(() => false, []);
  const getText = useCallback(() => null, []);
  const reconnect = useCallback(() => {}, []);

  return {
    enabled: false,
    status: "disabled" as CollabStatus,
    synced: true,
    bound: false,
    role: "Owner" as const,
    canEdit: true,
    peers: [],
    selfColor: DEFAULT_COLOR,
    savedAt: null,
    fatalError: null,
    viewers: [],
    registerEditor,
    unregisterEditor,
    undo,
    redo,
    getText,
    reconnect,
  };
}
