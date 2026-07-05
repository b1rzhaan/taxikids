"use client";

import { createContext, useContext, useEffect, useState } from "react";
import { getSession, setSession as persist } from "./api";
import type { Session } from "./types";

interface AuthState {
  session: Session | null;
  ready: boolean;
  signIn: (s: Session) => void;
  signOut: () => void;
}

const AuthCtx = createContext<AuthState>({
  session: null,
  ready: false,
  signIn: () => {},
  signOut: () => {},
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    setSession(getSession());
    setReady(true);
  }, []);

  const signIn = (s: Session) => {
    persist(s);
    setSession(s);
  };
  const signOut = () => {
    persist(null);
    setSession(null);
  };

  return (
    <AuthCtx.Provider value={{ session, ready, signIn, signOut }}>
      {children}
    </AuthCtx.Provider>
  );
}

export const useAuth = () => useContext(AuthCtx);

// Roles that are allowed into the web cabinet.
export const CABINET_ROLES = ["operator", "admin", "accountant"];
