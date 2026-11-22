"use client";

import React, { createContext, useContext, useEffect, useState } from "react";

export type PortalLanguage = "ar" | "en";
export type PortalTheme = "dark" | "light";

interface PortalPreferencesContextValue {
  lang: PortalLanguage;
  isRTL: boolean;
  theme: PortalTheme;
  isDark: boolean;
  setLang: (lang: PortalLanguage) => void;
  toggleLang: () => void;
  setTheme: (theme: PortalTheme) => void;
  toggleTheme: () => void;
}

const PortalPreferencesContext = createContext<PortalPreferencesContextValue | null>(null);

const LANG_STORAGE_KEY = "t2h_exam_lang";
const THEME_STORAGE_KEY = "t2h_exam_theme";

export function PortalPreferencesProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  const [lang, setLangState] = useState<PortalLanguage>("ar");
  const [theme, setThemeState] = useState<PortalTheme>("dark");

  // Hydrate user preferences after mount so static HTML never mismatches
  useEffect(() => {
    try {
      const savedLang = window.localStorage.getItem(LANG_STORAGE_KEY);
      if (savedLang === "ar" || savedLang === "en") {
        setLangState(savedLang);
      }

      const savedTheme = window.localStorage.getItem(THEME_STORAGE_KEY);
      if (savedTheme === "dark" || savedTheme === "light") {
        setThemeState(savedTheme);
      } else if (
        window.matchMedia &&
        window.matchMedia("(prefers-color-scheme: light)").matches
      ) {
        setThemeState("light");
      }
    } catch {
      // Ignore storage access errors in restricted contexts
    }
  }, []);

  useEffect(() => {
    if (typeof document === "undefined") return;
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
    document.documentElement.dataset.theme = theme;
  }, [lang, theme]);

  const setLang = (next: PortalLanguage) => {
    setLangState(next);
    try {
      window.localStorage.setItem(LANG_STORAGE_KEY, next);
    } catch {
      // Ignore storage errors
    }
  };

  const toggleLang = () => {
    setLang(lang === "ar" ? "en" : "ar");
  };

  const setTheme = (next: PortalTheme) => {
    setThemeState(next);
    try {
      window.localStorage.setItem(THEME_STORAGE_KEY, next);
    } catch {
      // Ignore storage errors
    }
  };

  const toggleTheme = () => {
    setTheme(theme === "dark" ? "light" : "dark");
  };

  return (
    <PortalPreferencesContext.Provider
      value={{
        lang,
        isRTL: lang === "ar",
        theme,
        isDark: theme === "dark",
        setLang,
        toggleLang,
        setTheme,
        toggleTheme,
      }}
    >
      {children}
    </PortalPreferencesContext.Provider>
  );
}

export function usePortalPreferences(): PortalPreferencesContextValue {
  const ctx = useContext(PortalPreferencesContext);
  if (!ctx) {
    return {
      lang: "ar",
      isRTL: true,
      theme: "dark",
      isDark: true,
      setLang: () => {},
      toggleLang: () => {},
      setTheme: () => {},
      toggleTheme: () => {},
    };
  }
  return ctx;
}
